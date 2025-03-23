defmodule PhilHtml.Helpers do

  def essai do
    "La fonctions essai dans les helpers par défaut."
  end

  def path(path) when is_binary(path) do
    ~s(<span class="path">#{path}</span>)
  end
  def p(arg), do: path(arg)

  @doc """
  Demande de construction de la table des matières

  Cette fonction se contente de placer la marque pour savoir où 
  la table des matières devra être inscrite à la fin.
  """
  def toc do
    "PHILTOCPHIL"
  end


  # À mettre dans un module à transmettre à la compilation
  # def constant_get(key) do
  #   Constants.get(key)
  # end


end