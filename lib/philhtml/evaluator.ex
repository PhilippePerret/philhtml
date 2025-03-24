defmodule PhilHtml.Evaluator do
  @moduledoc """
  Module consacré à l'évaluation live du code HTML (html.heex) 
  formaté
  """

  alias PhilHtml.Parser

  import PhilHtml.UsefullMethods


  # @reg_heex_variable ~r/<\%\=(.+?)\%>/

  @reg_phil_code_on_compile ~r/<\:([rfc])?[ \n]+(.+)[ \n]+\:>/Ums
  @reg_phil_code_on_render ~r/<\:\:([rfc])?[ \n]+(.+)[ \n]+\:\:>/Ums
  def reg_phil_code_on_render, do: @reg_phil_code_on_render

  @doc """
  Evalue le code <: ... :> à la compilation

  """
  def evaluate_on_compile(html, options) do
    Regex.scan(@reg_phil_code_on_compile, html)
    |> Enum.reduce(html, fn [tout, transformers, content], html ->
      rempl = evaluate_code(content, transformers, options)
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
    Regex.scan(@reg_phil_code_on_render, phtml.heex)
    |> Enum.reduce(phtml, fn [tout, transformers, content], phtml ->
      # IO.inspect(content, label: "[evaluate_on_render] Code à évaluer")
      rempl = evaluate_code(content, transformers, options)
      # IO.inspect(rempl, label: "[evaluate_on_render] Remplacement de `#{content}'")
      %{phtml | html: String.replace(phtml.html, tout, rempl)}
    end)
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
  def evaluate_code(content, transformers, options) do
    options = if options[:variables] do options else
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
    found_function = Regex.run(@reg_function_with_args, content)
    if is_nil(found_function) do nil else
      [_tout, fn_name, fn_params] = found_function
      dmodule = module_helper_for?(fn_name, fn_params, options)
      cond do
        is_nil(dmodule) -> 
          ~s(<span class="error">** Unknown function: #{fn_name}/#{Enum.count(StringTo.list(fn_params))}</span>)
        true -> 
          [module, fn_name, fn_params] = dmodule
          evaluate_in(module, fn_name, fn_params)
      end
    end
  end

  def evaluate_code_as(:variable, content, options) do
    if is_empty(options[:variables]) do nil else
      Keyword.get(options[:variables], String.to_atom(content))
    end
  end

  def evaluate_code_as(:elixir, content, options) do
    # IO.inspect(content, label: "Contenu elixir à évaluer")
    # IO.inspect(options[:variables], label: "Variables")
    {result, _variables} = Code.eval_string(content, options[:variables])
    result
  end




  def evaluate_in(module, fn_name, fn_params) when is_binary(fn_name) do
    evaluate_in(module, String.to_atom(fn_name), fn_params)
  end
  def evaluate_in(module, fn_name, fn_params) when is_binary(fn_params) do
    evaluate_in(module, fn_name, StringTo.list(fn_params))
  end
  def evaluate_in(module, fn_name, fn_params) do
    apply(module, fn_name, fn_params)
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
    arity  = Enum.count(fn_params)

    # IO.inspect(fn_name, label: "fn_name")
    # IO.inspect(fn_params, label: "fn_params")
    # IO.inspect(arity, label: "arity")

    # Liste de tous les modules
    (Keyword.get(options, :helpers, []) ++ [PhilHtml.Helpers])
    |> Enum.filter(fn module ->
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
      [module, fn_name, fn_params]
    end)
    |> Enum.at(0, nil)
  end


end