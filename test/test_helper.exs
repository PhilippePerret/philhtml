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

  def entete_code(compiler \\ false) do
    ~s(<meta charset=\"utf-8\">\n) <>
    if compiler do
      path = Path.join(["assets", "css", "common.css"])
      ~s(<style type="text/css">) <> File.read!(path) <> "</style>"
    else
      # path = Path.expand
      """
      <link rel=\"stylesheet\" href=\"#{Path.expand(Path.join([__DIR__, ".."]))}/assets/css/common.css\" />
      """ 
    end |> String.trim()
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

    2.  Si +source+ est un chemin de fichier, on s'assure de détruire
        le fichier .html fin de ne pas le charger par erreur.
  """
  def test_cycle_complet(source, expected, options \\ []) do
    # - Options -
    options = if Keyword.has_key?(options, :compilation) do options else
      Keyword.put(options, :compilation, false)
    end

    # On ajoute toujours les helpers, sauf si on ne doit pas
    options = 
    if options[:no_helpers] do options else
      if Keyword.has_key?(options, :helpers) do
        if Enum.member?(options[:helpers], HelperDeTest) do options else
          Keyword.put(options, :helpers, options[:helpers] ++ [HelperDeTest])
        end
      else
        Keyword.put(options, :helpers, [HelperDeTest])
      end
    end

    # - Destruction du fichier .html si nécessaire (cf. note 2) -
    if File.exists?(source) do 
      remove_html_file_from(source)
    end

    actual = PhilHtml.to_html(source, options) |> String.trim() |> String.replace("\n", "")
    expected = """
    #{entete_code(options[:compilation])}
    #{expected}
    """ |> String.trim() |> String.replace("\n", "")
    assert(actual == expected)
  end


  defp remove_html_file_from(source) do
    html_file =
      if Path.extname(source) == ".html" do source else
        affix = Path.basename(source, Path.extname(source))
        Path.join([Path.dirname(source), "#{affix}.html"])
      end
    if File.exists?(html_file) do
      File.rm(html_file)
    end
  end
end