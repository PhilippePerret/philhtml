defmodule PhilHtml.Evaluator do
  @moduledoc """
  Module consacré à l'évaluation live du code HTML (html.heex) 
  formaté
  """

  # alias PhilHtml.Parser

  import UsefullMethods


  # @reg_heex_variable ~r/<\%\=(.+?)\%>/

  @reg_phil_code_on_compile ~r/<\:([rfc])?[ \n]+(.+)[ \n]+\:>/Ums
  @reg_phil_code_on_render ~r/<\:\:([rfc])?[ \n]+(.+)[ \n]+\:\:>/Ums
  def reg_phil_code_on_render, do: @reg_phil_code_on_render


  @doc """
  @api
  Fonction publique permettant de détemplatiser le texte.

  L'utilisation typique de cette méthode se fait avec les mails. On
  a une série de destinataires qui doivent recevoir un mail person-
  nalisé. Dans un premier temps, on prépare le mail à l'aide de :
    dataphil = PhilHtml.to_data("/path/to/mail.phil", params...)
  Ensuite, pour personnaliser les subjets (subject) et les corps
  de texte (html_body), on les envoie à cette fonction.
    subject   = PhilHtml.Evaluator.customize(subject, dataphil)
    htmlbody  = PhilHtml.Evaluator.customize(htmlbody, dataphil)
  @return
  """
  def customize(string, phtml) do
    phtml = Map.put(phtml, :heex, string)
    evaluate_on_render(phtml)
  end

  @doc """
  Retourne directement le string personnalisé
  """
  def customize!(string, phtml) do
    customize(string, phtml).html
  end

  @doc """
  Evalue le code <: ... :> à la compilation

  """
  def evaluate_on_compile(html, options) do
    # IO.inspect(options, label: "OPTIONS DANS evaluate_on_compile")
    Regex.scan(@reg_phil_code_on_compile, html)
    |> Enum.reduce(html, fn [tout, transformers, content], html ->
      rempl = evaluate_code(content, transformers, options)
      rempl =
        if String.match?(transformers, ~r/f/) do
          # Si c'est du code qui doit être formaté ensuite, il
          # faut ajouter "<:f "
          rempl 
        else
          # Sinon, le texte sera protégé pour ne pas être
          # transformé par les corrections normales
          "PROTECTEDPHHT#{rempl}PHHTPROTECTED"
        end
      String.replace(html, tout, "#{rempl}")
    end)
  end

  @doc """

  Note : contrairement à la précédente, cette fonction reçoit et
  retourne une structure PhilHtml

  @param {PhilHtml} phtml La structure de construction
  
  @return {PhilHtml} La structure de construction avec le nouveau 
  code évalué.
  """
  def evaluate_on_render(phtml) do
    # IO.inspect(phtml.heex, label: "\n[evaluate_on_render] Code complet à évaluer")
    options = phtml.options
    phtml = %{phtml | html: phtml.heex}
    no_evaluation = Keyword.get(options, :evaluation, true) === false

    # TODO il faudrait mettre un verrou pour ne pas pouvoir avoir phtml.heex
    # nil
    phtml =
    if is_nil(phtml.heex) do
      %{phtml | heex: ""}
    else
      phtml
    end
    
    Regex.scan(@reg_phil_code_on_render, phtml.heex)
    |> Enum.reduce(phtml, fn [tout, transformers, content], phtml ->
      # IO.inspect(content, label: "[evaluate_on_render] Code à évaluer")
      rempl = 
      if no_evaluation do
        raw = if String.match?(transformers, ~r/c/), do: "raw ", else: ""
        "<%= #{raw}#{content} %>"
      else
        evaluate_code(content, transformers, options)
      end
      # IO.inspect(rempl, label: "[evaluate_on_render] Remplacement de `<:: #{content} ::>'")
      %{phtml | html: String.replace(phtml.html, tout, rempl)}
    end)
    # |> IO.inspect(label: "\n+++ phtml après évaluation au rendu")
  end

  @doc """
  Fonction généraliste qui évalue (à la compilation ou au rendu) le
  code +content+, le transforme éventuellement avec les transformers.

  Pour procéder à cette opération, la fonction opère à trois niveaux :

    1)  Si c'est une fonction, elle essaie de la trouver dans un des helpers
    2)  elle essaie de remplacer la variable potentiellement donnée en argument
    3)  elle essaie enfin d'évaluer le code tel quel (il peut contenir
        des variables définies dans les options)

  @param {String} content   Le texte/code à évaluer
  @param {List} transformers  Les transformeurs, une liste pouvant contenir "f", "c" ou "r"
                              f: seulement le formatage
                              c: seulement la correction
                              r: le code tel quel
                              rien:  le code sera corrigé et formaté
  @param {Keyword} options
  @param {List} options.helpers   Les helpers à utiliser (ajoutés au helper par défaut PhilHtml.Helpers)
  @param {Map}  options.variables Des variables définies
  """
  def evaluate_code(content, _transformers, options) do
    options = 
      if options[:variables] do 
        options 
      else
        Keyword.put(options, :variables, [])
      end
    # IO.inspect(content, label: "\nContenu à évaluer…")
    # IO.inspect(options, label: "\navec les options…")

    evaluated = evaluate_code_as(:function, content, options)
    evaluated = evaluated || evaluate_code_as(:variable, content, options)
    evaluated = evaluated || evaluate_code_as(:elixir, content, options)

    evaluated
    # |> IO.inspect(label: "Contenu évalué")
  end

  @reg_function_with_args ~r/^([a-zA-Z_0-9\?\!]+)\((.*)\)$/Um

  def evaluate_code_as(:function, content, options) do
    # IO.inspect(options, label: "[evaluate_code_as] OPTIONS")
    found_function = Regex.run(@reg_function_with_args, content)
    if is_nil(found_function) do nil else
      [_tout, fn_name, fn_params] = found_function
      dmodule = module_helper_for?(fn_name, fn_params, options)
      # IO.inspect(dmodule, label: "MODULE trouvé pour #{fn_name}")
      cond do
        is_nil(dmodule) -> 
          ~s(<span class="error">** Unknown function: #{fn_name}/#{Enum.count(StringTo.list(fn_params))}</span>)
        true -> 
          apply(__MODULE__, :evaluate_in, dmodule)
        end
    end
  end

  def evaluate_code_as(:variable, content, options) do
    res = if is_empty(options[:variables]) do nil else
      Keyword.get(options[:variables], String.to_atom(content), nil)
    end
    case res do
    nil -> 
      # Si le code n'a pas été trouvé comme variable, on regarde si
      # ça n'est pas une fonction sans parenthèses
      dmodule = module_helper_for?(content, [], options)
      if is_nil(dmodule) do nil else
        apply(__MODULE__, :evaluate_in, dmodule)
      end
    _ -> res
    end
  end

  def evaluate_code_as(:elixir, content, options) do
    # IO.inspect(content, label: "Contenu elixir à évaluer")
    # IO.inspect(options, label: "\nOptions")
    {result, _variables} = Code.eval_string(content, options[:variables])
    result
  end




  def evaluate_in(module, fn_name, fn_params, options) when is_binary(fn_name) do
    evaluate_in(module, String.to_atom(fn_name), fn_params, options)
  end
  def evaluate_in(module, fn_name, fn_params, options) when is_binary(fn_params) do
    evaluate_in(module, fn_name, StringTo.list(fn_params), options)
  end
  def evaluate_in(module, fn_name, fn_params, options) do
    fn_params = rationnalize_function_params(fn_params, options)
    apply(module, fn_name, fn_params)
  end

  def rationnalize_function_params(fn_params, options) do
    # IO.inspect(fn_params, label: "Params")
    # IO.inspect(options, label: "\nOptions avec Params")
    fn_params
    |> Enum.map(fn param ->
      cond do
        is_atom(param) and Keyword.has_key?(options[:variables], param) ->
          Keyword.get(options[:variables], param)
        is_atom(param) ->
          # Ça pourrait être une fonction d'un des modules, sans arguments
          param
        true -> 
          param
      end
    end)
    # |> IO.inspect(label: "Nouveaux paramètres")
  end


  @doc """
  Cherche le module définissant la méthode +fn_name+ avec le
  nombre de paramètres fournis.

  @return [module, fn_name:atom, fn_params:list] ou nil
  """
  def  module_helper_for?(fn_name, fn_params, options) when is_binary(fn_name) do
    module_helper_for?(String.to_atom(fn_name), fn_params, options)
  end
  def  module_helper_for?(fn_name, fn_params, options) when is_binary(fn_params) do
    module_helper_for?(fn_name, StringTo.list(fn_params), options)
  end
  def module_helper_for?(fn_name, fn_params, options) do
    # IO.inspect(options, label: "OPTIONS POUR VOIR")
    arity  = Enum.count(fn_params)

    # IO.inspect(fn_name, label: "fn_name")
    # IO.inspect(fn_params, label: "fn_params")
    # IO.inspect(arity, label: "arity")

    # Liste de tous les modules
    (Keyword.get(options, :helpers, []) ++ [PhilHtml.Helpers])
    # |> IO.inspect(label: "\n\n[philhtml] Liste des helpers")
    |> Enum.filter(fn module ->
        # IO.inspect(module, label: "Test sur module")
        case Code.ensure_loaded(module) do
          {:error, _err} -> raise "Le module #{module} est inconnu…"
          _ -> 
            cond do
              Kernel.function_exported?(module, fn_name, arity) ->
                true
              true ->
                false
            end    
        end
      end)
    |> Enum.map(fn module ->
      [module, fn_name, fn_params, options]
    end)
    |> Enum.at(0, nil)
    # |> IO.inspect(label: "MODULE CHOISI POUR #{fn_name}")
  end


end