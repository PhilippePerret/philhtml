defmodule SafeString do

  import UsefullMethods

  @doc """
  Retourne l'entier correspondant à la chaine, même 
  lorsqu'elle est vide, dans lequel cas elle renvoie 0 ou la valeur
  par défaut.
  Produit une erreur si la chaine ne correspond pas à un entier.

  ## Doctests

    iex> SafeString.to_integer("12")
    12

    iex> SafeString.to_integer("")
    0

    iex> SafeString.to_integer("", 12)
    12

  """
  def to_integer(string, default \\ 0) do
    case nil_if_empty(string, [trim: true]) do
    nil -> default
    trimed_string -> String.to_integer(trimed_string)
    end
  end

end