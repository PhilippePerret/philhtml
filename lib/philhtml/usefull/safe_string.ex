defmodule SafeString do

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

  @doc """
  Return nil si +string+ est une chaine vide ou vidish.

  +options+
    :trim     Si true, on retourne la chaine trimée
              Default: nil

  ## Examples
  
    iex> SafeString.nil_if_empty("")
    nil

    iex> SafeString.nil_if_empty("    ")
    nil

    iex> SafeString.nil_if_empty("bonjour")
    "bonjour"

    iex> SafeString.nil_if_empty(" bonjour   ", [trim: true])
    "bonjour"

  """
  def nil_if_empty(foo, options \\ [trim: false]) when is_binary(foo) or is_nil(foo) do
    cond do
    is_binary(foo) -> 
      trimed_foo = String.trim(foo)
      if trimed_foo == "" do
        nil
      else
        if options[:trim] do
          trimed_foo
        else
          foo
        end
      end
    is_nil(foo) -> nil
    end
  end

end