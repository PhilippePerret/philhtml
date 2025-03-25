defmodule PhilHtml.Parser do
  @moduledoc """
  Module qui s'occupe de parser le fichier pour en tirer :
  - le front matter (metadata)
  - les codes à traiter
  - les codes à laisser tels quels
  """

  alias PhilHtml.{Compiler, Evaluator}

  import SafeString

  @sep "XxXxX"

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
    |> Compiler.pre_compile(:remove_comments)
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
  @reg_blocs_code_in_html  ~r/^<(pre)>(<code(?:.+)<\/code>)<\/pre>/Usm
  @reg_codes_inline_in_html ~r/<(code)>(.+)<\/code>/U

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
        # La marque de bloc peut être suivie de paramètres
        [params, code] = if Regex.match?(~r/\n/, code) do
          String.split(code, "\n", [parts: 2])
        else 
          # Par exemple pour le code entre backstick ou le code à
          # évaluer
          ["", code] 
        end
        section = {type, String.trim(code), String.trim(params)}
        %{
          content: String.replace(collector.content, tout, "LIHP#{Enum.count(collector.sections)}SEP"),
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
      String.replace(collector, "LIHP#{index}SEP", "LIHPSEPLMTH#{type}#{@sep}#{params}#{@sep}#{content}LIHPSEPLMTH")
    end)
    |> String.split("LIHPSEPLMTH")
    |> Enum.map(fn content -> 
      content = String.trim(content)
      if String.match?(content, ~r/^([a-z]+)#{@sep}(.+)/) do
        [type_section, params_section, content_section] = String.split(content, "#{@sep}", [parts: 3, trim: false])
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
    {:string, "String avec LIHP0LMTH.", [{:code, "code"}]}

    iex> Parser.parse_raw_code_inline("`code``autre code`")
    {:string, "LIHP0LMTHLIHP1LMTH", [{:code, "code"}, {:code, "autre code"}]}

    iex> Parser.parse_raw_code_inline("String avec <%= heex_code %>.")
    {:string, "String avec LIHP0LMTH.", [{:heex, "heex_code"}]}

  @return un tuplet {:string, {String} content, {List} raws} où 
  +content+ est le contenu avec des LIHP<x>LMTH à la place des
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
        new_content = String.replace(content, tout, "LIHP#{Enum.count(raws)}LMTH")
        new_raws    = raws ++ [{typereg, String.trim(code)}]
        {:string, new_content, new_raws}
      end)
    end)
  end


  @doc """
  Extrait les codes à évaluer au rendu.

  Note : la fonction restore_render_evaluations_from(content, 
          evaluations) produit le contraire.

  @return [{String} content, {List} evaluation]
  """
  def extract_render_evaluations_from(content) do
    Regex.scan(Evaluator.reg_phil_code_on_render, content)
    |> Enum.reduce({content, []}, fn [tout, transformers, code], collector ->
      {content, codes} = collector
      code_mark = "PHIL#{Enum.count(codes)}CODE"
      {
        String.replace(content, tout, code_mark),
        codes ++ [tout]
      }
    end)
  end
  @doc """
  Remet les codes à évaluer au rendu dans le contenu

  NB: Pas très idiomatique de la mettre ici (ça n'est pas du parsing,
      mais ça se discute). Cf. la fonction ci-dessus.

  @param {String} content Le contenu dans lequel il faut remettre les codes à évaluer au rendu
  @param {List} codes Liste de duplet contenant l'intégralité du code, avec ses balises <:: ... ::>
  """
  def restore_render_evaluations(content, codes) do
    codes
    |> Enum.with_index()
    |> Enum.reduce(content, fn {code, index}, content ->
      code_mark = "PHIL#{index}CODE"
      String.replace(content, code_mark, code)
    end)
  end

end