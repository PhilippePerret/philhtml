defmodule PhilHtml.FormaterTest do
  use ExUnit.Case

  Code.require_file("test/fixtures/helpers/helper_de_test.ex")
  # => HelperDeTest

  import PhilHtml.Formatter
  import PhilHtml.TestMethods

  alias Transformer, as: T


  doctest PhilHtml.Formatter

  describe "traitement de guillemets" do

    @tag :skip
    test "dans un simple code" do
      source = """
      "bonjour" et "au revoir" dans `du "code"`
      code:
      "pour" voir
      :code
      """ |> String.trim()
      expected = """
      #{entete_code()}
      « bonjour » et « au revoir » dans <code>du "code"</code>
      <pre><code>
      "pour" voir
      </code></pre>
      """ |> String.trim()
      actual = PhilHtml.to_html(source)
      assert(actual == expected)
    end

  end
  
  
end
