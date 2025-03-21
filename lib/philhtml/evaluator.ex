defmodule PhilHtml.Evaluator do
  @moduledoc """
  Module consacré à l'évaluation live du code HTML (html.heex) 
  formaté
  """

  alias PhilHtml.Parser


  @reg_heex_variable ~r/<\%\=(.+?)\%>/


  @doc """
  Méthode principale évaluant les <%= ... %> dans le code formaté.

  """
  def evaluate(%{html: html} = data, options) when is_map(data) do

    variables = Keyword.get(options, :variables, %{})
    |> IO.inspect(label: "Variables")
    options = Keyword.put(options, :variables, variables)

    # On parse pour isoler les codes (ne pas les traiter)
    [sections, options] = Parser.dispatch_html_content([html, options])
    IO.inspect(sections, label: "SECTIONS DANS ÉVALUATE")

    sections
    |> Enum.map(fn section -> 
      case section.type do
        :string -> evaluate_section(section.content, options)
        :code   -> "<code>#{section.content}</code>"
        :pre    -> "<pre>#{section.content}</pre>"
      end
    end)
    |> Enum.join("\n")

  end

  def evaluate_section(html, options) do
    IO.inspect(html, label: "fourni à evaluate_section/2")
    Regex.scan(@reg_heex_variable, html) 
    |> IO.inspect(label: "Résultat du scan")
    |> Enum.reduce(html, fn [tout, elixir], collector ->
      elixir = String.trim(elixir)
      IO.inspect(elixir, label: "Found")

      found_function = Regex.run(~r/^([a-zA-Z_0-9\?]+)\((.+)\)$/U, elixir)

      evaluated_elixir =
      if is_nil(found_function) do
        {evaluated_elixir, _binding} = Code.eval_string(elixir, options[:variables])
        evaluated_elixir
      else
        [_tout, fn_name, fn_params] = found_function
        fn_name   = String.to_atom(fn_name)
        fn_params = StringTo.list(fn_params)
        arity     = Enum.count(fn_params)
        cond do
          Kernel.function_exported?(PhilHtml.Helpers, fn_name, arity) ->
            evaluate_in(PhilHtml.Helpers, fn_name, fn_params)
          # TODO: voir aussi dans les modules fournis
          true -> raise "Fonction inconnue : #{fn_name}/#{arity}"
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
end