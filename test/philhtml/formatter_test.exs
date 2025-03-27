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
  end #/describe
end
