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

  end #/describe

  describe "inclusion" do

    @tag :skip
    test "d'un fichier css au même niveau que le document" do
      source = "./test/fixtures/textes/with_css_same_level.phil"
      expected = """
      <style type="text/css">body {width: 2000px}</style>
      <p>Le fichier css se trouve à la même place que ce fichier .phil.</p>
      """
      test_cycle_complet(source, expected, [compilation: true])
    end

  end
end