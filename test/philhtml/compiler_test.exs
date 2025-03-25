defmodule PhilHtml.CompilerTest do
  use ExUnit.Case
  import PhilHtml.TestMethods
  
  import PhilHtml.Compiler
  doctest PhilHtml.Compiler

  describe "Un document avec des erreurs" do

    @tag :skip
    test "produit un document avec les erreurs affichés" do
      source = """
      ---
      css = ["./un/fichier/inexistant"]
      ---
      Un bon paragraphe.
      <: fonction_inexistante() :>
      """
      expected = """
      <link rel=\"stylesheet\" href=\"./un/fichier/inexistant\" />
      <p>Un bon paragraphe.</p>
      <p><span class="error">** Unknown function: fonction_inexistante/0</span></p>
      """
      test_cycle_complet(source, expected)
    end


  end
end