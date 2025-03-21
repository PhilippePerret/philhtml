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
  def evaluate(%{html: html} = data, options) do

    variables = Keyword.get(options, :variables, %{})
    |> IO.inspect(label: "Variables")
    options = Keyword.put(options, :variables, variables)

    # On parse pour isoler les codes (ne pas les traiter)
    [sections, options] = Parser.dispatch_html_content([html, options])

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
    # IO.inspect(html, label: "fourni à evaluate_section/2")
    Regex.scan(@reg_heex_variable, html) 
    |> IO.inspect(label: "Résultat du scan")
    |> Enum.reduce(html, fn [tout, elixir], collector ->
      elixir = String.trim(elixir)
      IO.inspect(elixir, label: "Found")
      {evaluated_elixir, _binding} = Code.eval_string(elixir, options[:variables])
      IO.inspect(evaluated_elixir, label: "Code évalué")
      String.replace(collector, tout, evaluated_elixir)
      |> IO.inspect(label: "avec le code remplacé")
    end)
  end

end