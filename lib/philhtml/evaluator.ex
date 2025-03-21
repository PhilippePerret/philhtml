defmodule PhilHtml.Evaluator do
  @moduledoc """
  Module consacré à l'évaluation live du code HTML (html.heex) 
  formaté
  """


  @reg_heex_variable ~r/<\%\=(.+?)\%>/


  @doc """
  Méthode principale évaluant les <%= ... %> dans le code formaté.

  """
  def evaluate(%{ :html => html} = data, options) do
    final_html = html

  end

end