defmodule PhilHtml.BlocsTests do
  use ExUnit.Case

  describe "un bloc de code" do

    test "avec l'option remove_trailing_spaces" do
      source = """
      code:
         Pour voir
         Des espace avant
         être supprimés
      :code
      code: remove_trailing_spaces
         Pour voir
         Des espace avant
         être supprimés
      :code
      """
      expected = """
      <meta charset=\"utf-8\">
      <pre><code>
      Pour voir
         Des espace avant
         être supprimés
      </code></pre>
      <pre><code>
      Pour voir
      Des espace avant
      être supprimés
      </code></pre>
      """
      actual = PhilHtml.to_html(source)
      assert(actual == String.trim(expected))
    end
  end
end