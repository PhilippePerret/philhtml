defmodule PhilHtml.ParseTest do
  use ExUnit.Case

  alias PhilHtml.Parser

  doctest PhilHtml.Parser

  test "le parse d'un texte seul est valide" do
    source = """
    Un texte seul.
    """
    actual = Parser.parse(source, [])
    expected = [
      [{:string, "Un texte seul.", []}],
      [{:metadata, []}]
    ]
    assert(actual == expected)
  end

  test "un texte avec une section :raw" do
    source = """
    Un texte.
    raw:
    Une section raw
    :raw
    Un autre texte
    """
    actual = Parser.parse(source, [])
    expected = [
      [
        {:string, "Un texte.", []},
        {:raw, "Une section raw", nil},
        {:string, "Un autre texte", []}
      ],
      [{:metadata, []}]
    ]
    assert(actual == expected)
  end

  test "un texte avec metadata" do
    source = """
    ---
    mavariable = "Ma valeur"
    ---
    Un texte.
    """
    actual = Parser.parse(source, [])
    expected = [
      [{:string, "Un texte.", []}],
      [metadata: [mavariable: "Ma valeur"]]
    ]
    assert(actual == expected)
  end

  test "un texte avec du code en ligne" do
    source = """
    Un `texte` avec <%= "un code en ligne" %> pour voir.
    """
    actual = Parser.parse(source, [])
    expected = [
      [{:string, "Un $PHILHTML1$ avec $PHILHTML0$ pour voir.", [{:heex, ~s("un code en ligne")}, {:code, "texte"}]}],
      [metadata: []]
    ]
    assert(actual == expected)
  end 


end
