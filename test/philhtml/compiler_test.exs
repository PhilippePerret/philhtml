defmodule PhilHtml.CompilerTest do
  use ExUnit.Case

  import PhilHtml.TestMethods

  describe "Un document avec des erreurs" do

    # @tag :skip
    test "produit un document avec les erreurs affichés" do
      source = """
      ---
      css = ["./un/fichier/inexistant"]
      ---
      Un bon paragraphe.
      <: fonction_inexistante() :>
      """
      
      expected = """
      #{entete_code()}
      <link rel=\"stylesheet\" href=\"./un/fichier/inexistant\" />
      <p>Un bon paragraphe.</p>
      <p><span class="error">** Unknown function: fonction_inexistante/0</span></p>
      """

      actual = PhilHtml.to_html(source)

      assert(actual == expected |> String.trim())
    end


  end
end