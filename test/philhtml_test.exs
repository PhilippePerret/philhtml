defmodule PhilHtmlTest do
  use ExUnit.Case

  import PhilHtml.TestMethods

  doctest PhilHtml

  describe "avec du code" do
    
    @tag :skip
    test "simple" do

      source = """
      Un simple texte.
      """
      expected = "<p>Un simple texte.</p>"
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "définissant un path inexistant (analysé en tant que code)" do
      source = "/Users/qui/nexiste/pas.phil"
      expected = "<p>/Users/qui/nexiste/pas.phil</p>"
      test_cycle_complet(source, expected)
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
      test_cycle_complet(source, expected)
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
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "contenant une inclusion" do
      inclusion_path = Path.absname("./test/fixtures/textes/simple_include.phil")
      inclusion_post = Path.absname("./test/fixtures/textes/simple_post_include.phil")
      source = """
      inc: #{inclusion_path}
      Du texte pour voir.
      post/include: #{inclusion_post}
      """
      expected = """
      <p>Du texte simple inclus.</p>
      <p>Du texte pour voir.</p>
      Du texte inclus \#{à la fin} pour voir.
      """
      test_cycle_complet(source, expected)
    end

  end

  describe "avec un fichier" do

    @tag :skip
    test "un fichier simple" do
      src = Path.absname("test/fixtures/textes/simple.phil")
      actual = PhilHtml.to_html(src)
      expected = "<p>Je suis un fichier très simple.</p>"
      assert(actual =~ expected)
    end

    @tag :skip
    test "un fichier simple vers un nom différent" do
      src = Path.absname("test/fixtures/textes/simple.phil")
      dest_expected = Path.absname("test/fixtures/textes/smp.html.heex")
      File.exists?(dest_expected) && File.rm(dest_expected)
      PhilHtml.to_html(src, [dest_name: "smp.html.heex"])
      assert File.exists?(dest_expected)
    end
    @tag :skip
    test "un fichier simple vers un dossier différent" do
      src = Path.absname("test/fixtures/textes/simple.phil")
      dest_expected = Path.absname("test/fixtures/html/simple.html")
      File.exists?(dest_expected) && File.rm(dest_expected)
      PhilHtml.to_html(src, [dest_folder: "../html"])
      assert File.exists?(dest_expected)
    end
    
    @tag :skip
    test "un fichier simple vers un nom et dossier différent" do
      src = Path.absname("test/fixtures/textes/simple.phil")
      dest_expected = Path.absname("test/fixtures/html/smp.html.erb")
      File.exists?(dest_expected) && File.rm(dest_expected)
      PhilHtml.to_html(src, [dest_folder: "../html", dest_name: "smp.html.erb"])
      assert File.exists?(dest_expected)
    end

    # @tag :skip
    test "un fichier .html à jour retourne le bon code" do
      src   = Path.absname("test/fixtures/textes/simple.phil")
      dest  = Path.absname("test/fixtures/textes/simple.html")
      File.exists?(dest) && File.rm(dest)
      assert !File.exists?(dest)
      # On commence par le faire pour qu'il soit actualisé
      res_on_build = PhilHtml.to_html(src)
      assert(File.exists?(dest), "le fichier .html devrait avoir été construit")
      assert(PhilHtml.File.after?(dest, src), "le fichier .phil devrait avoir été modifié après…")
      # --- Test ---
      res = PhilHtml.to_html(src)
      # --- Vérification ---
      assert(res == res_on_build)
    end

    @tag :skip
    test "et un appel à to_data/2 pour obtenir les données mais pas de fichier" do
      src = Path.absname("test/fixtures/textes/simple.phil")
      dest = Path.absname("test/fixtures/textes/simple.html")
      res = PhilHtml.to_data(src, [no_file: true])
      # |> IO.inspect(label: "Retour to_data")
      
      assert(is_struct(res, PhilHtml), "Le retour de to_data devrait être une structure PhilHtml")
      assert(!File.exists?(dest), "Le fichier destination #{dest} ne devrait pas exister")
    end
    
    @tag :skip
    test "et un appel à to_data/2 avec un fichier avec front-matter" do
      src = Path.absname("test/fixtures/textes/avec_frontmatter.phil")
      res = PhilHtml.to_data(src, [no_file: true, variables: [pseudo: "Pilou"]])
      # |> IO.inspect(label: "Retour to_data")

      assert(is_struct(res, PhilHtml), "Le retour devrait être une structure PhilHtml")

    end


    @tag :skip
    test "contenant un css" do
    end

    @tag :skip
    test "contenant un javascript" do
    end

    # @tag :skip
    test "contenant des includes définis en path relatifs" do
      # Il y a un problème particulier, ici, c'est que le fichier 
      # dans les metadata 'folder', dont nous avons besoin pour 
      # inclure les fichiers, mais l'inclusion se passe avant le
      # découpage des fichiers. Pour pallier ce problème, on peut
      # exceptionnellement, lire rapidement le frontmatter sans 
      # rien toucher du fichier encore. On ne peut pas inverser
      # les méthodes, sinon on ne pourrait pas ajouter de frontmatter
      # de cette manière-là.
      source = Path.absname("./test/fixtures/textes/avec_inclusions_in_folder.phil")
      expected = """
      <p>Je suis un fichier très simple.</p>
      <p>Je suis en <em>italique</em> et en <strong>gras</strong>.</p>
      <pre><code>
      Avec du code.
      </code></pre>

      <p class="error">** (ArgumentError) File `mauvais/path’ (fullpath: \"./test/fixtures/textes/mauvais/path\") unfound.</p>
      """
      remove_html_of_phil(source)
      test_cycle_complet(source, expected)
    end

  end # describe "avec des fichiers"

  def remove_html_of_phil(philpath) do
    affx = Path.basename(philpath, Path.extname(philpath))
    dest = Path.join([Path.dirname(philpath), "#{affx}.html"])
    File.exists?(dest) && File.rm(dest)
  end
end
