defmodule PhilHtml.PhilFormatterTest do
  use ExUnit.Case
  import PhilHtml.TestMethods

  describe "un texte simple" do
    
    @tag :skip
    test "rend un code simple" do
      source = """
      Ceci est mon texte.
      Pour voir si tout sera traité.
      En même temps.
      """
      expected = """
      <p>Ceci est mon texte.</p>
      <p>Pour voir si tout sera traité.</p>
      <p>En même temps.</p>
      """
      test_cycle_complet(source, expected)
    end
  end

  describe "un texte balisé au début" do

    @tag :skip
    test "est mis entre balises" do

      [
       [ "span.classe:Mon texte", ~s(<span class="classe">Mon texte</span>)]
      ] |> Enum.each(fn [source, expected] -> 
        test_cycle_complet(source, expected)
      end)
    end
  end

  describe "les variables" do
    @tag :skip
    test "passées aux fonctions par atom peuvent être des variables d'entête" do
      source = """
      ---
      mavar = Marion
      ---
      <: mafun(:mavar) :>
      """
      expected = """
      <p>Bonjour Marion.</p>
      """
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "passées aux fonctions par atom peuvent être des variables fournies" do
      source = """
      <: mafun(:mavar) :>
      """
      expected = """
      <p>Bonjour Élie.</p>
      """
      test_cycle_complet(source, expected, [variables: %{mavar: "Élie"}])
    end

    @tag :skip
    test "passées aux fonctions sans être des variables sont gardées telles quelles" do
      source = """
      <: mafun(:marion_variable) :>
      """
      expected = """
      <p>Bonjour marion_variable.</p>
      """
      test_cycle_complet(source, expected)
    end

  end #/describe "les variables"
end