defmodule PhilHtml.Helpers do

  def essai do
    "La fonctions essai dans les helpers par défaut."
  end

  def path(path) when is_binary(path) do
    ~s(<span class="path">#{path}</span>)
  end
  def p(arg), do: path(arg)


  # À mettre dans un module à transmettre à la compilation
  # def constant_get(key) do
  #   Constants.get(key)
  # end


end