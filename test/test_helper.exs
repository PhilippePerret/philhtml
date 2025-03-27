Code.append_path("./test/fixtures/helpers")
Code.require_file("./test/fixtures/helpers/helper_de_test.ex")
ExUnit.start()

defmodule PhilHtml.TestMethods do
  use ExUnit.Case

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

  @doc """
  Pour faire un test en utilisant le code complet, du début à la fin.

  Notes
  -----
    1.  Par défaut, les codes CSS et JS sont ajoutés dans le document
        mais ce comportement n'est pas possible pour ce test (sans 
        lire chaque fois ces documents). Donc, pour le moment on 
        force l'option compilation à false si elle n'est pas définie
        explicitement.
  """
  def test_cycle_complet(source, expected, options \\ []) do
    # - Options -
    options = if Keyword.has_key?(options, :compilation) do options else
      Keyword.put(options, :compilation, false)
    end

    actual = PhilHtml.to_html(source, options) |> String.trim()
    expected = """
    #{entete_code()}
    #{expected}
    """ |> String.trim()
    assert(actual == expected)
  end

end