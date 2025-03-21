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

end
