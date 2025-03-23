defmodule PhilHtml.EvaluatorTest do
  use ExUnit.Case

  alias PhilHtml.Evaluator

  doctest PhilHtml.Evaluator

  describe "un texte avec " do

    @tag :skip
    test "code simple en ligne à évaluer comme code elixir à la compilation" do
      source = "<: 2 + 3 :>"
      expected = "5"
      actual = Evaluator.evaluate_on_compile(source, [])
      assert(actual == expected)
    end

    @tag :skip
    test "code simple en ligne à évaluer comme code elixir avec des variables" do
      source    = "<: 2 + vari :>"
      expected  = "9"
      actual = Evaluator.evaluate_on_compile(source, [variables: [vari: 7]])
      assert(actual == expected)
    end

    @tag :skip
    test "code simple en bloc à évaluer à la compilation" do
      source = """
      <:
      2 + 3
      :>
      """
      |> String.trim()
      expected = "5"
      actual = Evaluator.evaluate_on_compile(source, [])
      assert(actual == expected |> String.trim())
    end

    @tag :skip
    test "code de variable en ligne à évaluer à la compilation" do
      source = "<: mavariable :>"
      actual = Evaluator.evaluate_on_compile(source, [variables: [mavariable: "Une variable pour voir"]])
      expected = "Une variable pour voir"
      assert(actual == expected)
    end

    @tag :skip
    test "code d'helper personnalisé, en ligne, à évaluer à la compilation" do
      source    = "<: monhelper() :>"
      expected  = "Retour de mon helper"
      actual    = Evaluator.evaluate_on_compile(source, [helpers: [HelperDeTest]])
      assert(actual == expected)
    end

    @tag :skip
    test "code d'helper personnalisé, en bloc, à évaluer à la compilation" do
      source    = """
      <:
      monhelper()
      :>
      """ |> String.trim()
      expected  = "Retour de mon helper"
      actual    = Evaluator.evaluate_on_compile(source, [helpers: [HelperDeTest]])
      assert(actual == expected)
    end


  end
  
end
