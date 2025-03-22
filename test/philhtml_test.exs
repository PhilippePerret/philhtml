defmodule PhilHtmlTest do
  use ExUnit.Case
  doctest PhilHtml

  describe "avec du code" do
    
    @tag :skip
    test "simple" do

      source = """
      Un simple texte.
      """
      actual = PhilHtml.to_html(source)
      expected = "<p>Un simple texte.</p>"
      assert(actual == expected)
    end

    @tag :skip
    test "définissant un path inexistant (analysé en tant que code)" do
      src = "/Users/qui/nexiste/pas.phil"
      actual = PhilHtml.to_html(src)
      expected = "<p>/Users/qui/nexiste/pas.phil</p>"
      assert(actual == expected)
    end

    @tag :skip
    test "contenant un css" do
      source = """
      ---
      css = ["/fichier.css", "/autre_fichier.css"]
      ---
      Ce code définit deux fichiers css.
      """
      expected = """
      <link rel="stylesheet" href="/fichier.css" />
      <link rel="stylesheet" href="/autre_fichier.css" />
      <p>Ce code définit deux fichiers css.</p>
      """
      actual = PhilHtml.to_html(source)
      assert(actual == String.trim(expected))
    end

    @tag :skip
    test "contenant un javascript" do
      source = """
      ---
      javascript = ["/fichier.js", "/assets/autre_fichier.js"]
      ---
      Ce code définit deux fichiers JavaScript.
      """
      expected = """
      <p>Ce code définit deux fichiers JavaScript.</p>
      <script defer src="/fichier.js"></script>
      <script defer src="/assets/autre_fichier.js"></script>
      """
      actual = PhilHtml.to_html(source)
      assert(actual == expected |> String.trim())
    end

    @tag :skip
    test "contenant une inclusion" do
      inclusion_path = Path.absname("./test/fixtures/textes/simple_include.phil")
      inclusion_post = Path.absname("./test/fixtures/textes/simple_post_include.phil")
      source = """
      include(#{inclusion_path})
      Du texte pour voir.
      post/include(#{inclusion_post})
      """
      expected = """
      <p>Du texte simple inclus.</p>
      <p>Du texte pour voir.</p>
      Du texte inclus \#{à la fin} pour voir.
      """
      actual = PhilHtml.to_html(source)
      assert(actual == expected |> String.trim())
    end

  end

  describe "avec un fichier" do

    @tag :skip
    test "un fichier simple" do
      src = Path.absname("test/fixtures/textes/simple.phil")
      actual = PhilHtml.to_html(src)
      expected = "<p>Je suis un fichier très simple.</p>"
      assert(actual == expected)
    end

    @tag :skip
    test "contenant un css" do
    end

    @tag :skip
    test "contenant un javascript" do
    end

    # @tag :skip
    test "contenant des includes définis en path relatifs" do
      source = Path.absname("./test/fixtures/textes/avec_inclusions_in_folder.phil")
      expected = """
      <p>Je suis un fichier très simple.</p>
      <p>Je suis en <em>italique</em> et en <strong>gras</strong>.</p>
      <pre><code>
      Avec du code.
      </code></pre>
      <p class="error">** (ArgumentError) File `mauvais/path' (fullpath: \"./test/fixtures/textes/mauvais/path\") unfound.</p>
      """

      remove_html_of_phil(source)

      actual = PhilHtml.to_html(source)
      assert(actual == expected |> String.trim())
    end
  end

  def remove_html_of_phil(philpath) do
    affx = Path.basename(philpath, Path.extname(philpath))
    dest = Path.join([Path.dirname(philpath), "#{affx}.html"])
    File.exists?(dest) && File.rm(dest)
  end
end
