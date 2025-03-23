defmodule PhilHtml.Helpers do

  def essai do
    "La fonctions essai dans les helpers par défaut."
  end

  def path(path) when is_binary(path) do
    ~s(<span class="path">#{path}</span>)
  end
  def p(arg), do: path(arg)

  @doc """
  Construction de la table des matières.

  MAIS… Comment obtenir le code ?… Je pense qu'il faut un traitement 
  spécial de cette fonction et peut-être même utiliser plutôt une
  marque propre.
  """
  def toc do
    "{html: Je dois apprendre à construire la table des matières.}"
  end


  # À mettre dans un module à transmettre à la compilation
  # def constant_get(key) do
  #   Constants.get(key)
  # end


end