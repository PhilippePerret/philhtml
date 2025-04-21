defmodule PhilHtml.BlocsTests do
  use ExUnit.Case

  import PhilHtml.TestMethods

  describe "un bloc de code" do
    
    @tag :skip
    test "avec l'option as_doc" do
      source = """
      code: as_doc
      Un code qui doit apparaitre comme du code.
      :code
      """
      expected = """
      <pre class="as_doc"><code>
      Un code qui doit apparaitre comme du code.
      </code></pre>
      """
      test_cycle_complet(source, expected)
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
      test_cycle_complet(source, expected)
    end
  end
end