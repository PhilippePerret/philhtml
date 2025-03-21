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
        {String.to_atom(var), value}
      end)
    end
    options = Keyword.put(options, :metadata, metadata)
    [String.trim(content), options]
    # |> IO.inspect(label: "Fin de découpe")
  end

  @reg_sections_raw_phil ~r/^(raw|code)\:(.+)\:\1/Usm
  @reg_sections_raw_html ~r/^<(pre)>(<code(?:.+)<\/code>)<\/pre>/Usm
  @reg_sections_code_html ~r/<(code)>(.+)<\/code>/U

  @doc """
  Fonction qui prend le contenu du fichier .phil (hors front-matter) 
  et le découpe en portions de code à ne pas toucher et de code à
  formater.

  Noter qu'au retour les options sont mises dans la liste principale.

  @return [metadata, content{list}, options]
  """
  def dispatch_phil_content([content, options]) do
    dispatch_content([content, options], @reg_sections_raw_phil)
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
      IO.inspect(accu.content, label: "\nContenu fourni au SCAN")
      IO.inspect(regex, label: "Regexp")
      Regex.scan(regex, accu.content)
      |> IO.inspect(label: "[dispatch_content] Résultat du SCAN")
      |> Enum.reduce(accu, fn [tout, type, code], collector ->
        section = %{type: String.to_atom(type), content: String.trim(code)}
        %{
          content: String.replace(collector.content, tout, "$PHILSEP$"),
          sections: collector.sections ++ [section]
        }
      end)
    end)
    |> IO.inspect(label: "DATA CONTENT FINAL")

    sections = data_content.sections
    content  = data_content.content

    splited_content = 
    String.split(content, "\$PHILSEP\$")
    |> Enum.with_index()
    |> Enum.map(fn {section, index} -> 
      [
        %{type: :string, content: String.trim(section)},
        Enum.at(sections, index)
      ]
    end)
    |> List.flatten()
    |> Enum.filter(fn x -> 
      not is_nil(x) and not ( x.content == "" )
    end)
    |> IO.inspect(label: "Final Splited Content")

    [splited_content, options]
  end

end