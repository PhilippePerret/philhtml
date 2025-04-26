defmodule PhilHtml.EvaluatorTest do
  use ExUnit.Case

  import PhilHtml.TestMethods

  doctest PhilHtml.Evaluator

  describe "un texte avec " do

    @tag :skip
    test "code simple en ligne à évaluer comme code elixir à la compilation" do
      source = "<: 2 + 3 :>"
      expected = "<p>5</p>"
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "code simple en ligne à évaluer comme code elixir avec des variables" do
      source    = """
      ---
      vari = 7
      ---
      <: 2 + vari :>
      """
      expected  = "<p>9</p>"
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "code simple en bloc à évaluer à la compilation" do
      source = """
      <: 2 + 3 :>
      """
      expected = "<p>5</p>"
      test_cycle_complet(source, expected)
    end

    @tag :skip
    test "code de variable en ligne à évaluer à la compilation" do
      source = "<: mavariable :>"
      expected = "<p>Une variable pour voir</p>"
      test_cycle_complet(source, expected, [variables: [mavariable: "Une variable pour voir"]])
    end

    @tag :skip
    test "code d'helper personnalisé, en ligne, à évaluer à la compilation" do
      source    = "<: monhelper() :>"
      expected  = "<p>Retour de mon helper</p>"
      test_cycle_complet(source, expected, [helpers: [HelperDeTest]])
    end

    @tag :skip
    test "code d'helper personnalisé, en bloc, à évaluer à la compilation" do
      source = """
      <: monhelper :>
      """
      expected = "<p>Retour de mon helper</p>"
      test_cycle_complet(source, expected, [helpers: [HelperDeTest]])
    end


  end
  
end
