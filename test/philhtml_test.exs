defmodule PhilHtmlTest do
  use ExUnit.Case
  doctest PhilHtml

  test "un texte simple" do

    source = """
    Un simple texte.
    """
    actual = PhilHtml.to_html(source)
    expected = """
    <p>Un simple texte</p>
    """
    assert(actual == expected)
  end

  test "un fichier simple" do
    src = Path.absname("test/fixtures/textes/simple.phil")
    actual = PhilHtml.to_html(src)
    expected = "<p>Je suis un fichier très simple.</p>"
    assert(actual == expected)
  end

  test "un path inexistant est analysé en tant que code" do
    src = Path.absname("./qui/nexiste/pas.phil")
    actual = PhilHtml.to_html(src)
    expected = "<p>./qui/nexiste/pas.phil</p>"
    assert(actual == expected)
  end

end
