defmodule PhilHtml.Compiler do
  @moduledoc """
  Typiquement, c'est le module qui s'occupe d'insérer les assets
  dans le code final.

  Ça doit se faire juste avant l'évaluation.
  """

  @doc """
  Fonction principale qui ajoute s'il le faut les assets pour 
  produire le code final.
  """
  def compile(phtml) when is_struct(phtml, PhilHtml) do
    phtml =
    if is_nil(phtml.metadata[:css]) do phtml else
      compile_css(phtml)
    end
    phtml =
    if is_nil(phtml.metadata[:javascript]) do phtml else
      compile_javascript(phtml)
    end
    # Retour
    phtml
  end

  def compile_css(phtml) do
    phtml # TODO
  end
  def compile_javascript(phtml) do
    phtml # TODO
  end
end