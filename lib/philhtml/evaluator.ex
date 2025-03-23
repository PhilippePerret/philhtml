defmodule PhilHtml.Evaluator do
  @moduledoc """
  Module consacré à l'évaluation live du code HTML (html.heex) 
  formaté
  """

  alias PhilHtml.Parser


  @reg_heex_variable ~r/<\%\=(.+?)\%>/


  @doc """
  Méthode principale évaluant les <%= ... %> dans le code formaté.

  @return {HTMLString} Le code HTML final, tel qu'il doit être envoyé
  au navigateur client.
  """
  def evaluate(phtml) when is_struct(phtml, PhilHtml) do
    heex      = phtml.heex
    options   = phtml.options
    _variables = Keyword.get(options, :variables, %{})
    _metadata  = phtml.metadata

    # On parse pour isoler les codes à ne pas traiter
    [sections, options] = Parser.dispatch_html_content([heex, options])
    # IO.inspect(sections, label: "SECTIONS DANS ÉVALUATE")

    html = 
    sections
    |> Enum.map(fn {type, content, _raws} -> 
      case type do
        :string -> evaluate_section(content, options)
        :code   -> "<code>#{content}</code>"
        :pre    -> 
          IO.inspect(content, label: "Content à mettre dans le <pre>")
          "<pre>#{content}</pre>"
      end
    end)
    |> Enum.join("\n")

    %{phtml | html: html}
  end

  def evaluate_section(html, options) do
    # IO.inspect(html, label: "fourni à evaluate_section/2")
    Regex.scan(@reg_heex_variable, html) 
    # |> IO.inspect(label: "Résultat du scan")
    |> Enum.reduce(html, fn [tout, elixir], collector ->
      elixir = String.trim(elixir)
      # IO.inspect(elixir, label: "Found")

      found_function = Regex.run(~r/^([a-zA-Z_0-9\?]+)\((.+)\)$/U, elixir)

      evaluated_elixir =
      if is_nil(found_function) do
        {evaluated_elixir, _binding} = Code.eval_string(elixir, options[:variables])
        evaluated_elixir
      else
        [_tout, fn_name, fn_params] = found_function
        dmodule = module_helper_for?(fn_name, fn_params, options)
        cond do
          is_nil(dmodule) -> 
            raise "Fonction inconnue : #{fn_name}/#{Enum.count(StringTo.list(fn_params))}"
          true -> 
            [module, fn_name, fn_params] = dmodule
            evaluate_in(module, fn_name, fn_params)
        end

      end

      IO.inspect(evaluated_elixir, label: "Code évalué")
      String.replace(collector, tout, evaluated_elixir)
      |> IO.inspect(label: "avec le code remplacé")
    end)
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
      cond do    
        Kernel.function_exported?(module, fn_name, arity) -> true
        true -> false
      end
      # |> IO.inspect(label: "Condition pour module #{module} #{inspect fn_name}/#{arity}")
    end)
    |> Enum.map(fn module ->
      [module, fn_name, fn_params]
    end)
    |> Enum.at(0, nil)
  end


end