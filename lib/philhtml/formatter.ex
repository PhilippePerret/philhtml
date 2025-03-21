defmodule PhilHtml.Formatter do

  @doc """
  @main

  @public
  """
  def formate(data_path) do
    File.read!(data_path[:src])
    |> Parser.parse() # => {:original_content, :metadata}
    |> formate()
  end

  def formate(%{original_content: content} = data) do

  end

end