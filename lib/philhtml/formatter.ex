defmodule PhilHtml.Formatter do

  alias PhilHtml.Parser

  @doc """
  @main

  @return {:ok|:error, rien|erreur}
  @public
  """
  def formate(data_path, options) do
    IO.puts "-> formate(#{inspect data_path}, #{inspect options})"
    html_code = 
    File.read!(data_path[:src])
    |> Parser.parse(options) # => {:original_content, :metadata}
    |> IO.inspect(label: "\n\n[pour code html.heex] APRÈS PARSE")
    |> formate()
    |> IO.inspect(label: "\n\nCODE HTML.HEEX FINAL")
    File.write(data_path[:dst], html_code)
  end

  @doc """
  Fonction principale qui formate tout le contenu et retourne le 
  code html (seuls subsiste les <% ... %> qui seront évalués à la
  volée)

  @return {HTMLString} Code html.heex de la page
  """
  def formate([splited_content, options]) do
    splited_content
    |> Enum.map(fn section ->
      formate(section.type, section, options)
    end)
    |> Enum.join("\n")
  end

  def formate(:raw, section, options) do
    """
    <pre><code>
    #{section.content}
    </code></pre>
    """
  end

  def formate(:code, section, options) do
    """
    <code>#{section.content}</code>
    """
  end

  def formate(:string, section, options) do
    """
    <p>Pour le moment : #{section.content}</p>
    """
  end

end