defmodule PhilHtml.BlocsTests do
  use ExUnit.Case

  describe "un bloc de code" do
    
    @tag :skip
    test "avec l'option as_doc" do
      source = """
      code: as_doc
      Un code qui doit apparaitre comme du code.
      :code
      """
      expected = """
      <meta charset=\"utf-8\">
      <pre class="as_doc"><code>
      Un code qui doit apparaitre comme du code.
      </code></pre>
      """
      actual = PhilHtml.to_html(source)
      assert(actual == expected |> String.trim() )
    end

    @tag :skip
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