defmodule PhilHtml.Parser do
  @moduledoc """
  Module qui s'occupe de parser le fichier pour en tirer :
  - le front matter (metadata)
  - les codes à traiter
  - les codes à laisser tels quels
  """


  @doc """
  @main
  Fonction principale qui parse le code d'un fichier .phil pour :
  – en extraire le front-matter
  - en séparer les codes à ne pas toucher des codes à formater
  - retourne le résultat pour traitement
  @params {String} phil_content Le contenu complet du fichier .phil
  @params {Keyword} options Liste des options
  """
  def parse(phil_content, options) when is_binary(phil_content) do
    phil_content
    |> split_front_matter(options)
    |> front_matter_to_metadata(options)
    |> dispatch_phil_content() # =>  [content_splitted, options (avec metadata)]
  end




  def split_front_matter(str, options) do
    parts = String.split(str, "---")
    if Enum.count(parts) == 3 do
      [_rien | usefull_parts] = parts
      usefull_parts
    else
      [nil, str]
    end
  end

  def front_matter_to_metadata([frontmatter, content], options) do
    metadata =
    if is_nil(frontmatter) do
      []
    else
      String.trim(frontmatter)
      |> String.split("\n")
      |> Enum.map(fn line -> 
        [var, value] = String.split(line, "=") |> Enum.map(fn s -> String.trim(s) end)
        {String.to_atom(var), StringTo.value(value)}
      end)
    end
    options = Keyword.put(options, :metadata, metadata)
    [String.trim(content), options]
    # |> IO.inspect(label: "Fin de découpe")
  end

  @reg_sections_raw_phil  ~r/^(raw)\:(.+)\:raw/Usm
  @reg_code_inline_phil   ~r/`(.+)`/U
  @reg_sections_heex_phil ~r/<\%\=(.+)\%>/U
  @reg_sections_raw_html  ~r/^<(pre)>(<code(?:.+)<\/code>)<\/pre>/Usm
  @reg_sections_code_html ~r/<(code)>(.+)<\/code>/U

  @doc """
  Fonction qui prend le contenu du fichier .phil (hors front-matter) 
  et le découpe en portions de code à ne pas toucher et de code à
  formater.

  Noter qu'au retour les options sont mises dans la liste principale.

  @return [metadata, content{list}, options]
  """
  def dispatch_phil_content([content, options]) do
    dispatch_content([content, options], [@reg_sections_raw_phil])
  end

  def dispatch_html_content([content, options]) do
    dispatch_content([content, options], [@reg_sections_raw_html, @reg_sections_code_html])
  end

  def dispatch_content([content, options], regex) do
    # Pour être sûr d'avoir un texte au début et pas un code/raw
    content = "\n\n\n" <> content

    regexes = cond do
      is_list(regex) -> regex
      true -> [regex]
    end


    data_content = 
    Enum.reduce(regexes, %{content: content, sections: []}, fn regex, accu -> 
      # IO.inspect(accu.content, label: "\nContenu fourni au SCAN")
      # IO.inspect(regex, label: "Regexp")
      Regex.scan(regex, accu.content)
      # |> IO.inspect(label: "[dispatch_content] Résultat du SCAN")
      |> Enum.reduce(accu, fn [tout, type, code], collector ->
        type = case type do
          "<%"  -> :heex
          "`"   -> :code # NON, ÇA CASSE LA LIGNE
          _ -> String.to_atom(type)
        end
        section = {type, String.trim(code)}
        %{
          content: String.replace(collector.content, tout, "$PHILSEP-#{Enum.count(collector.sections)}$"),
          sections: collector.sections ++ [section]
        }
      end)
    end)
    # |> IO.inspect(label: "DATA CONTENT FINAL")

    sections = data_content.sections
    content  = data_content.content

    splited_content = 
    sections
    |> Enum.with_index()
    |> Enum.reduce(content, fn {{type, content}, index}, collector ->
      String.replace(collector, "\$PHILSEP-#{index}\$", "$PHILSEP$#{type}::#{content}$PHILSEP$")
    end)
    |> String.split("$PHILSEP$")
    |> Enum.map(fn content -> 
      content = String.trim(content)
      if String.match?(content, ~r/^([a-z]+)::(.+)/) do
        [type_section, content_section] = String.split(content, "::", [parts: 2, trim: true])
        {String.to_atom(type_section), content_section, nil}
      else
        parse_raw_code_inline(content) # => {:string, content, [...]}
        
      end
    end)
    |> Enum.filter(fn {type, content, raws} -> 
      not is_nil(content) and not (content == "")
    end)
    # |> IO.inspect(label: "Final Splited Content")

    [splited_content, options]
  end

  @doc """
  Fonction qui reçoit le string +content+ d'un code à formater et
  met de côté les codes en ligne

  ## Examples

    iex> Parser.parse_raw_code_inline("simple string")
    {:string, "simple string", []}

    iex> Parser.parse_raw_code_inline("String avec `code`.")
    {:string, "String avec $PHILHTML0$.", [{:code, "code"}]}

    iex> Parser.parse_raw_code_inline("`code``autre code`")
    {:string, "$PHILHTML0$$PHILHTML1$", [{:code, "code"}, {:code, "autre code"}]}

    iex> Parser.parse_raw_code_inline("String avec <%= heex_code %>.")
    {:string, "String avec $PHILHTML0$.", [{:heex, "heex_code"}]}

  @return un tuplet {:string, {String} content, {List} raws} où 
  +content+ est le contenu avec des $PHILHTML<x>$ à la place des
  code en ligne et +raws+ est une liste de tuplet contenant des
    {:heex, code HEEX à évaluer au chargement}
    {:code, code à évaluer à la compilation}
  """
  def parse_raw_code_inline(content) do
    [{:heex, @reg_sections_heex_phil}, {:code, @reg_code_inline_phil}]
    |> Enum.reduce({:string, content, []}, fn {typereg, regexpression}, collector ->
      Regex.scan(regexpression, content)
      |> Enum.reduce(collector, fn [tout, code], datacontent ->
        {:string, content, raws} = datacontent
        new_content = String.replace(content, tout, "$PHILHTML#{Enum.count(raws)}$")
        new_raws    = raws ++ [{typereg, String.trim(code)}]
        {:string, new_content, new_raws}
      end)
    end)
  end

end