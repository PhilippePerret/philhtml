defmodule PhilHtml.FormaterTest do
  use ExUnit.Case

  Code.require_file("test/fixtures/helpers/helper_de_test.ex")
  # => HelperDeTest

  alias Transformer, as: T

  import PhilHtml.Formatter # pour les doctest
  import PhilHtml.TestMethods

  # IO.puts "Les doctest Formatter sont à remettre"
  doctest PhilHtml.Formatter

  describe "traitement de guillemets" do

    @tag :skip
    test "dans un simple code" do
      source = """
      "bonjour" et "au revoir" dans `du "code"`
      code:
      "pour" voir
      :code
      """
      expected = """
      <p><nowrap>«&nbsp;bonjour&nbsp;»</nowrap> et <nowrap>«&nbsp;au</nowrap> <nowrap>revoir&nbsp;»</nowrap> dans <code>du "code"</code></p>
      <pre><code>
      "pour" voir
      </code></pre>
      """
      test_cycle_complet(source, expected)
    end

  end
  
  describe "Traitement des tables" do

    @tag :skip
    test "avec une table sans paramètres (simple)" do
      source = """
      Un simple paragraphe.
      table:
      cellule 1 | cellule 2
      :table
      Un autre paragraphe.
      """
      expected = """
      <p>Un simple paragraphe.</p>
      <table>
      <tr><td>cellule 1</td><td>cellule 2</td></tr>
      </table>
      <p>Un autre paragraphe.</p>
      """
      test_cycle_complet(source, expected)
    end


    @tag :skip
    test "avec une table avec paramètres" do
      source = """
      Un simple paragraphe.
      table: id=matable col_widths=[100,auto,25%]
      cellule 1 | cellule 2 | cellule 3
      :table
      Un autre paragraphe.
      """
      expected = """
      <p>Un simple paragraphe.</p>
      <table id="matable">
      <colgroup>
      <col width="100px" />
      <col width="auto" />
      <col width="25%" />
      </colgroup>
      <tr><td>cellule 1</td><td>cellule 2</td><td>cellule 3</td></tr>
      </table>
      <p>Un autre paragraphe.</p>
      """
      test_cycle_complet(source, expected)
    end

  end #/describe

  describe "à l'intérieur des cellules d'une table" do

    @tag :skip
    test "le code est formaté" do
      source = """
      table:
      De l'*italique* | du **gras** | du ***gras italique***
      :table
      """
      expected = """
      <table>
      <tr><td>De l’<em>italique</em></td><td>du <strong>gras</strong></td><td>du <strong><em>gras italique</em></strong></td></tr>
      </table>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "le code est évalué" do
      source = """
      table:
      <: 2 + 2 :> | <: "bonjour " <> "vous" :> | <::f essai("dans table") ::>
      :table
      """
      expected = """
      <table>
      <tr><td>4</td><td>bonjour vous</td><td>La fonction essai retourne ce qu’elle a reçu, dans table.</td></tr>
      </table>
      """
      test_cycle_complet(source, expected, [helpers: [HelperDeTest]])
    end
  end #/describe


  describe "un bloc :html" do

    @tag :skip
    test "ne voit pas ses balises corrigées" do
      source = """
      html:
      <div>Mon container</div>
      :html
      """
      expected = """
      <div>Mon container</div>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "peut être défini par <<<" do
      source = """
      <<<
      <div>Mon container</div>
      >>>
      """
      expected = """
      <div>Mon container</div>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "voit l'intérieur de son code mis en forme" do
      source = """
      ---
      cout = 42
      ---
      <<<
      <div>Mon 1^er *italic* vaut <: 2 + 3 :> ou <: cout :>.</div>
      >>>
      """
      expected = """
      <div>Mon 1<sup>er</sup> <em>italic</em> vaut 5 ou 42.</div>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "voit l'intérieur avec phil-amorce traité comme tel" do
      source = """
      html:
      <div>s.monspan:Le contenu</div>
      :html
      """
      expected = """
      <div><span class="monspan">Le contenu</span></div>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "corrige même à l'intérieur d'un intérieur" do
      source = """
      html:
      <div><span class="*donttouch">*italic*</span><span>**gras**</span></div>
      :html
      """
      expected = """
      <div><span class="*donttouch"><em>italic</em></span><span><strong>gras</strong></span></div>
      """
      test_cycle_complet(source, expected)
    end
  end #/describe bloc :html


  describe "un bloc :list (...)" do

    @tag :skip
    test "est mis en forme" do
      source = """
      Paragraphe avant.
      list:
      * item 1
      * item 2
      * item 3
      :list
      Un paragraphe après.
      ***
      * item 1
      * item 2
      * item 3
      ***
      """
      expected = """
      <p>Paragraphe avant.</p>
      <ul>
      <li>item 1</li>
      <li>item 2</li>
      <li>item 3</li>
      </ul>
      <p>Un paragraphe après.</p>
      <ul>
      <li>item 1</li>
      <li>item 2</li>
      <li>item 3</li>
      </ul>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "de type nombre est bien mis en forme" do
      source = """
      Paragraphe avant.
      list: numbered
      * item 1
      * item 2
      * item 3
      :list
      Un paragraphe entre les deux.
      *** numbered
      * item 1
      * item 2
      * item 3
      ***
      """
      expected = """
      <p>Paragraphe avant.</p>
      <ol>
      <li>item 1</li>
      <li>item 2</li>
      <li>item 3</li>
      </ol>
      <p>Un paragraphe entre les deux.</p>
      <ol>
      <li>item 1</li>
      <li>item 2</li>
      <li>item 3</li>
      </ol>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "sur plusieurs lignes" do
      source = """
      list:
      * Le premier item.

        :::
        Une ligne de code dedans.
        :::

      * Deuxième item.

      |||
      Cellule A1 | Cellule B1
      Cellule A2 | Cellule B2
      |||

      * Troisième item

        Juste un autre paragraphe.
      
      :list
      Un paragraphe à la suite.
      """
      expected = """
      <ul>
      <li><div>Le premier item.</div>
      <pre><code>Une ligne de code dedans.</code></pre></li>
      <li><div>Deuxième item.</div>
      <table>
      <tr><td>Cellule A1</td><td>Cellule B1</td></tr>
      <tr><td>Cellule A2</td><td>Cellule B2</td></tr>
      </table></li>
      <li><div>Troisième item</div>
      <div>Juste un autre paragraphe.</div></li>
      </ul>
      <p>Un paragraphe à la suite.</p>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "les corrections sont faites à l'intérieur" do
      source = """
      ---
      variable = ["valeur définie par une variable"]
      ---
      list:
      * Un *italic*,
      * Un **gras**,
      * Un ***gras italic***
      :list
      ***
      * Un __souligné__
      * 2 + 3 = <: 2 + 3 :>
      * Une <: Enum.at(variable, 0) :>.
      ***
      """
      expected = """
      <ul>
      <li>Un <em>italic</em>,</li>
      <li>Un <strong>gras</strong>,</li>
      <li>Un <strong><em>gras italic</em></strong></li>
      </ul>
      <ul>
      <li>Un <u>souligné</u></li>
      <li>2 + 3 = 5</li>
      <li>Une valeur définie par une variable.</li>
      </ul>
      """
      test_cycle_complet(source, expected)
    end

    # @tag :skip
    test "listes imbriquées" do
      source = """
      list:
      * Niveau 1
        list:
        * Niveau 1.1
          list:
          * Niveau 1.1.1
          * Niveau 1.1.2
          :list
        * Niveau 1.2
        * Niveau 1.3
        :list
      * Niveau 2
      * Niveau 3
      :list
      """
      expected = """
      <ul>
      <li>
      <div>Niveau 1</div>
      <ul>
      <li>
      <div>Niveau 1.1</div>
      <ul>
      <li>Niveau 1.1.1</li>
      <li>Niveau 1.1.2</li>
      </ul>
      </li>
      <li>Niveau 1.2</li>
      <li>Niveau 1.3</li>
      </ul>
      </li>
      <li>Niveau 2</li>
      <li>Niveau 3</li>
      </ul>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "une table ou autre code en items" do
      source = """
      list:
      * table: 
        C1 en item 1 | C2 en item 1
        :table
      * code:
        Du code en item 2
        :code
      :list
      """
      expected = """
      <ul>
      <li>
      <table>
      <tr><td>C1 en item 1</td><td>C2 en item 1</td></tr>
      </table>
      </li>
      <li>
      <pre><code>Du code en item 2</code></pre>
      </li>
      </ul>
      """
      test_cycle_complet(source, expected)
    end
  end #/describe bloc :list

  describe "fonction dans texte" do

    # @tag :skip
    test "doit être évaluée dans <: ... :>" do
      source = """
      Le nom de l'application est <: app_name() :>.
      """
      expected = """
      <p>Le nom de l’application est Mon application.</p>
      """
      test_cycle_complet(source, expected)
    end

    # @tag :skip
    test "ne doit pas être évaluée si directement dans texte" do
        # NB : Avant, on considérait que tout texte se présentant comme
      # une fonction était une fonction. Ça pose un problème avec les
      # texte par exemple inclusifs : "il ou elle est parti(e) sans…"
      # où "parti" est pris pour une fonction. Imposer maintenant 
      # l'utilisation de <: parti(e) :> si c'est vraiment une fonc-
      # tion
      source = """
      il ou elle est parti(e) sans laisser d'adresse.
      """
      expected = """
      <p>il ou elle est parti(e) sans laisser d’adresse.</p>
      """
      test_cycle_complet(source, expected)
    end

    # @tag :skip
    test "si variable inconnue, l'essayer comme fonction sans args" do
      source = """
      <: app_name :> est le nom de l'application.
      """
      expected = """
      <p>Mon application est le nom de l’application.</p>
      """
      test_cycle_complet(source, expected)
    end

  end

end
