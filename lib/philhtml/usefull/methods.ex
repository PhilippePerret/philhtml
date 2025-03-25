defmodule UsefullMethods do

  def add_error(phtml, erreur) when is_struct(phtml, PhilHtml) do
    %{phtml | errors: phtml ++ [erreur]}
  end

  def is_empty(liste) when is_list(liste) or is_map(liste) do
    Enum.count(liste) == 0
  end

@doc """
  Return nil si la chose fournie est vide, ce qui comprend :
    - une chaine vide
    - une liste/Keyword vide
    - une map vide
    - une structure vide
    - nil

  +options+
    :trim     Si true, on retourne la chaine trimée
              Default: nil

  ## Examples
  
    iex> nil_if_empty("")
    nil

    iex> nil_if_empty("    ")
    nil

    iex> nil_if_empty("bonjour")
    "bonjour"

    iex> nil_if_empty(" bonjour   ", [trim: true])
    "bonjour"

  """
  def nil_if_empty(foo, options \\ [trim: true])
  def nil_if_empty(lst, _options)  when is_list(lst) or is_map(lst) or is_struct(lst) do
    if is_empty(lst) do nil else lst end
  end
  def nil_if_empty(str, options) when is_binary(str) do
    trimed_str = String.trim(str)
    if trimed_str == "" do nil else
      if options[:trim] do trimed_str else str end
    end
  end
  def nil_if_empty(null, _options) when is_nil(null), do: nil

end