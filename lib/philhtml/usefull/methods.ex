defmodule PhilHtml.UsefullMethods do

  def add_error(phtml, erreur) when is_struct(phtml, PhilHtml) do
    %{phtml | errors: phtml ++ [erreur]}
  end

  def is_empty(liste) when is_list(liste) or is_map(liste) do
    Enum.count(liste) == 0
  end

end