defmodule PhilHtml.ParseTest do
  use ExUnit.Case

  alias PhilHtml.Parser

  doctest PhilHtml.Parser

  def test_parsing(code, expected, expected_metadata \\ nil, params \\ %{}) do
    phtml = Map.merge(%PhilHtml{raw_content: code}, params)
    actual = Parser.parse(phtml)
    # IO.inspect(actual, label: "ACTUAL")
    assert(actual.content == expected)
    if expected_metadata do
      assert(actual.metadata == expected_metadata)
    end
  end

  @tag :skip
  test "le parse d'un texte seul est valide" do
    source = "Un texte seul."
    expected = [{:string, "Un texte seul.", []}]
    test_parsing(source, expected)
  end

  # @tag :skip
  test "un texte avec une section :code" do
    source = """
    Un texte.
    code:
    table: col_widths=[100, auto]
    :code
    Un autre texte
    """
    expected = [
      {:string, "Un texte.", []},
      {:code, "table: col_widths=[100, auto]", nil},
      {:string, "Un autre texte", []}
    ]
    test_parsing(source, expected)
  end

  @tag :skip
  test "un texte avec une section :raw" do
    source = """
    Un texte.
    raw:
    Une section raw
    :raw
    Un autre texte
    """
    expected = [
      {:string, "Un texte.", []},
      {:raw, "Une section raw", nil},
      {:string, "Un autre texte", []}
    ]
    test_parsing(source, expected)
  end

  @tag :skip
  test "un texte avec une section html:" do
    source = """
    Un Texte.
    html: no_eval
    <p>Un texte sans évaluation.</p>
    :html
    html:
    <p>Un texte déjà mis en forme</p>
    :html
    Un autre texte
    """
    expected = [
      {:string, "Un Texte.", []},
      {:html, "<p>Un texte sans évaluation.</p>", "no_eval"},
      {:html, "<p>Un texte déjà mis en forme</p>", nil},
      {:string, "Un autre texte", []}
    ]
    test_parsing(source, expected)
  end

  @tag :skip
  test "un texte avec une section table:" do
    source = """
    table: col_widths=[100,auto]
    Celule 1 | Cellule 2
    :table
    """
    expected = [
      {:table, "Celule 1 | Cellule 2", "col_widths=[100,auto]"}
    ]
    test_parsing(source, expected)
  end

  @tag :skip
  test "un texte avec metadata" do
    source = """
    ---
    mavariable = "Ma valeur"
    ---
    Un texte.
    """
    expected = [
      {:string, "Un texte.", []}
    ]
    metadata = [
      {:mavariable, "Ma valeur"}
    ]
    test_parsing(source, expected, metadata)    
  end

  @tag :skip
  test "un texte avec du code en ligne" do
    source = """
    Un `texte` avec <%= "un code en ligne" %> pour voir.
    """
    expected = [
      {:string, "Un $PHILHTML1$ avec $PHILHTML0$ pour voir.", [{:heex, ~s("un code en ligne")}, {:code, "texte"}]}
    ]
    test_parsing(source, expected)
  end 


end
