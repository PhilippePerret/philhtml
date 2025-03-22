defmodule PhilHtml.UsefullMethods do

  def add_error(phtml, erreur) when is_struct(phtml, PhilHtml) do
    %{phtml | errors: phtml ++ [erreur]}
  end

end