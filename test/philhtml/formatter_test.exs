defmodule PhilHtml.FormaterTest do
  use ExUnit.Case

  Code.require_file("test/fixtures/helpers/helper_de_test.ex")
  # => HelperDeTest

  import PhilHtml.Formatter
  import PhilHtml.TestMethods

  alias Transformer, as: T


  doctest PhilHtml.Formatter


  def test_complet(source, expected) do
    source = source |> String.trim()
    expected = entete_code() <> "\n" <> expected |> String.trim()
    actual = PhilHtml.to_html(source, [helpers: [HelperDeTest]]) |> String.trim()
    assert(actual == expected)
  end

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
      test_complet(source, expected)
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
      """ |> String.trim()
      expected = """
      #{entete_code()}
      <p>Un simple paragraphe.</p>
      <table>
      <tr><td>cellule 1</td><td>cellule 2</td></tr>
      </table>
      <p>Un autre paragraphe.</p>
      """ |> String.trim()
      actual = PhilHtml.to_html(source)
      assert(actual == expected)
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
      test_complet(source, expected)
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
      test_complet(source, expected)
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
      test_complet(source, expected)
    end

  end #/describe
end
