defmodule PhilHtml.Parser do
  @moduledoc """
  Module qui s'occupe de parser le fichier pour en tirer :
  - le front matter (metadata)
  - les codes à traiter
  - les codes à laisser tels quels
  """

  alias PhilHtml.Compiler

  import SafeString

  @doc """
  @main
  Fonction principale qui parse le code d'un fichier .phil pour :
  – en extraire le front-matter
  - en séparer les codes à ne pas toucher des codes à formater
  - retourne le résultat pour traitement
  @params {PhilHtml} phtml Structure principale
  """
  def parse(phtml) when is_struct(phtml, PhilHtml) do
    phtml
    |> split_front_matter()
    |> front_matter_to_metadata()
    |> Compiler.pre_compile(:inclusions)
    |> explode_phil_content()
  end

  def split_front_matter(phtml) when is_struct(phtml, PhilHtml) do
    parts = String.split(String.trim(phtml.raw_content), "---", [parts: 3])
    if Enum.count(parts) == 3 do
      # <= Il y a un front-matter
      # => On ne prend que les parties utiles
      [_rien | usefull_parts] = parts
      Map.merge(phtml, %{
        frontmatter:  Enum.at(usefull_parts, 0),
        body:         Enum.at(usefull_parts, 1),
        raw_content:  Enum.at(usefull_parts, 1)
      })
    else phtml end
  end

  def front_matter_to_metadata(phtml) when is_struct(phtml, PhilHtml) do
    metadata =
    if is_nil(phtml.frontmatter) do
      []
    else
      String.trim(phtml.frontmatter)
      |> String.split("\n")
      |> Enum.map(fn line -> 
        [var, value] = String.split(line, "=") |> Enum.map(fn s -> String.trim(s) end)
        {String.to_atom(var), StringTo.value(value)}
      end)
    end
    %{ phtml | metadata: metadata}
  end

  # Deux expressions régulière pour traiter les blocs (html: code: 
  # table: etc.). Dans la première, on ne relève que les blocs 
  # `code:' car ceci peuvent contenir des exemples d'autres blocs qui
  # en tout état de cause ne doivent pas être traités. Voir par exem-
  # ple dans le manuel le bloc :
  #   «««««««««««««««««««««««««««««««««««««««««
  #   Pour définir les largeurs de colonnes :
  #   code:
  #   table: col_width=[]
  #   »»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
  @reg_bloc_code_phil  ~r/^(code)\:(.+)\:code/Usm
  @reg_blocs_phil  ~r/^(raw|table|html)\:(.+)\:\1/Usm

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
  def explode_phil_content(phtml) when is_struct(phtml, PhilHtml) do
    [content, _options] = explode_content([phtml.raw_content, phtml.options], [@reg_bloc_code_phil, @reg_blocs_phil])
    %{phtml | content: content}
  end

  @doc """
  Explosion du contenu mais quand c'est déjà du code HEEX et qu'on
  doit seulement évaluer les codes heex.
  """
  def dispatch_html_content([content, options]) do
    explode_content([content, options], [@reg_sections_raw_html, @reg_sections_code_html])
  end

  def explode_content([content, options], regex) do
    # Pour être sûr d'avoir un texte au début, même lorsque le code 
    # commence par une section :raw
    content = "\n\n\n" <> String.trim(content)

    # On utilise toujours une liste d'expressions régulières
    regexes = cond do
      is_list(regex) -> regex
      true -> [regex]
    end

    data_content = 
    Enum.reduce(regexes, %{content: content, sections: []}, fn regex, accu -> 
      # IO.inspect(accu.content, label: "\nContenu fourni au SCAN")
      # IO.inspect(regex, label: "Regexp")
      Regex.scan(regex, accu.content)
      # |> IO.inspect(label: "[explode_content] Résultat du SCAN")
      |> Enum.reduce(accu, fn [tout, type, code], collector ->
        type = case type do
          "<%"  -> :heex
          "`"   -> :inline_code
          _ -> String.to_atom(type)
        end
        [params, code] = String.split(code, "\n", [parts: 2])
        section = {type, String.trim(code), String.trim(params)}
        %{
          content: String.replace(collector.content, tout, "$PHILSEP-#{Enum.count(collector.sections)}$"),
          sections: collector.sections ++ [section]
        }
      end)
    end)
    # |> IO.inspect(label: "DATA CONTENT FINAL")

    sections = data_content.sections
    content  = data_content.content

    # Pour spliter les blocs en les gardant dans l'ordre
    splited_content = 
    sections
    |> Enum.with_index()
    |> Enum.reduce(content, fn {{type, content, params}, index}, collector ->
      String.replace(collector, "\$PHILSEP-#{index}\$", "$PHILSEP$#{type}::#{params}::#{content}$PHILSEP$")
    end)
    |> String.split("$PHILSEP$")
    |> Enum.map(fn content -> 
      content = String.trim(content)
      if String.match?(content, ~r/^([a-z]+)::(.+)/) do
        [type_section, params_section, content_section] = String.split(content, "::", [parts: 3, trim: false])
        params_section = nil_if_empty(params_section)
        {String.to_atom(type_section), content_section, params_section}
      else
        parse_raw_code_inline(content) # => {:string, content, [...]}
      end
    end)
    |> Enum.filter(fn {_type, content, _raws} -> 
      not is_nil(content) and not (content == "")
    end)
    # |> IO.inspect(label: "Final Splited Content")

    [splited_content, options]
  end

  @doc """
  Fonction qui reçoit le string +content+ d'un texte à formater et
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