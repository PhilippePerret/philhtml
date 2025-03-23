Code.append_path("./test/fixtures/helpers")
Code.require_file("./test/fixtures/helpers/helper_de_test.ex")
ExUnit.start()

defmodule PhilHtml.TestMethods do

  @doc """
  Ajoute l'entête commun à tous les codes formatés quand ils ne sont
  pas fournis par un fichier.

  @usage (dans les tests)

    Ajouter en haut du test : import PhilHtml.TestMethods
    Puis mettre dans l'expected :

    expected = \"\"\"
    \#{entete_code}
    ...
    \"\"\"

  """

  def entete_code do
    """
    <meta charset=\"utf-8\">
    <link rel=\"stylesheet\" href=\"common.css\" />
    """ |> String.trim()
  end

end