defmodule PhilHtml.Evaluator do
  @moduledoc """
  Module consacré à l'évaluation live du code HTML (html.heex) 
  formaté
  """


  @reg_heex_variable ~r/<\%\=(.+?)\%>/


  @doc """
  Méthode principale évaluant les <%= ... %> dans le code formaté.

  """
  def evaluate(%{html: html} = data, options) do

    binding = Keyword.get(options, :variables, %{})
    |> IO.inspect(label: "Binding")

    Regex.scan(@reg_heex_variable, html) 
    |> IO.inspect(label: "Résultat du scan")
    |> Enum.reduce(html, fn [tout, elixir], collector ->
      elixir = String.trim(elixir)
      IO.inspect(elixir, label: "Found")
      {evaluated_elixir, _binding} = Code.eval_string(elixir, binding)
      IO.inspect(evaluated_elixir, label: "Code évalué")
      String.replace(collector, tout, evaluated_elixir)
      |> IO.inspect(label: "avec le code remplacé")
    end)
  end

end