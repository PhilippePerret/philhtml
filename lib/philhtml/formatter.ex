defmodule PhilHtml.Formatter do

  alias PhilHtml.{Parser, Evaluator, Compiler}

  @doc """
  @main

  @return {:ok|:error, rien|erreur}
  @public
  """
  def formate(philcode, options) when is_binary(philcode) do
    formate(%PhilHtml{raw_content: philcode, options: options})
  end
  
  def formate(phtml) when is_struct(phtml, PhilHtml) do
    phtml
    |> Compiler.pre_compile(:first) # ne fait rien pour le moment
    |> Parser.parse()
    # |> IO.inspect(label: "\n\n[formate(phtml)] APRÈS PARSE")
    |> formate_content()
    # |> IO.inspect(label: "\n\n[formate(phtml)] APRÈS formate_content")
    |> Compiler.post_compile()
  end

  @doc """
  Fonction de formatage principal quand un fichier est fourni.
  @return :ok si tout s'est bien passé et {:error, erreur} en cas de
  problème.
  """
  def formate_file(phtml) when is_struct(phtml, PhilHtml) do
    phtml = %{phtml | raw_content: File.read!(phtml.file[:src])}
    phtml = formate(phtml)
    File.write(phtml.file[:dst], phtml.heex)
  end

  @doc """
  Fonction principale qui formate tout le contenu et retourne le 
  code html (seuls subsiste les <% ... %> qui seront évalués à la
  volée)

  @return {HTMLString} Code html.heex de la page
  """
  def formate_content(phtml) do
    %{phtml | heex: do_formate_content(phtml)}
  end
  defp do_formate_content(phtml) do
    options = Keyword.put(phtml.options, :metadata, phtml.metadata)
    phtml.content
    |> Enum.map(fn {type, section, raws} ->
      formate_section(type, %{content: section, raws: raws}, options)
    end)
    |> Enum.join("\n")
  end

  def formate_section(:raw, section, _options) do
    """
    <pre><code>
    #{section.content}
    </code></pre>
    """
  end

  def formate_section(:code, section, _options) do
    """
    <code>#{section.content}</code>
    """
  end

  def formate_section(:heex, section, _options) do
    """
    <%= #{section.content} %>
    """
  end

  def formate_section(:string, section, options) do
    metadata = Keyword.get(options, :metadata, [])
    options = if metadata[:default_tag] do
      Keyword.put(options, :default_tag, metadata[:default_tag])
    else options end
    section.content
    |> build_as_html(options)
  end



  @reg_helpers_functions ~r/\b([a-zA-Z0-9_]+)\((.*)\)/U
  @doc """
  Le Phil-Formateur part du principe que tout texte de la forme :
  'fonc_Tion(p)' — c'est-à-dire un string avec des minuscules, des
  majuscules et des traits plats, suivi d'une parenthèse ouverte,
  des arguments et une parenthèse fermée — est une fonction définie
  dans un helper.

  ## Examples
      Note : les exemples utilise les helpers qui se trouvent dans le
      dossier /test/fixtures/helpers/
      
      # Fonction commun (dans PhilHtml.Helpers)
      iex> evaluate_helpers_functions("C'est mon p(chemin/acces) pour venir.", [])
      ~s(C'est mon <span class="path">chemin/acces</span> pour venir.)

      # Fonction personnelle (dans module personnel)
      iex> evaluate_helpers_functions("mafonction()", [helpers: [HelperDeTest]])
      ~s(Texte pour remplacer la fonction `mafonction/0')

      # Fonction inconnue
      iex> evaluate_helpers_functions("mafonctioninexistante()", [helpers: [HelperDeTest]])
      ~s(<span class="error">Unknown function `mafonctioninexistante/0'</span>)
  """
  def evaluate_helpers_functions(code, options) do
    Regex.scan(@reg_helpers_functions, code)
    |> Enum.reduce(code, fn [tout, fn_name, fn_params], accu ->
      rempl = 
      case Evaluator.module_helper_for?(fn_name, fn_params, options) do
        nil -> 
          arity = StringTo.list(fn_params) |> Enum.count()
          ~s(<span class="error">Unknown function `#{fn_name}/#{arity}'</span>)
        tout -> 
          [module, fn_name, fn_params] = tout
          Evaluator.evaluate_in(module, fn_name, fn_params)
      end
      String.replace(accu, tout, rempl)
    end)
  end


  @smalltag_to_realtag %{
    ""  => "p", # par défaut
    "p" => "p",
    "d" => "div",
    "q" => "quote",
    "s" => "section"
  }

  @reg_amorce_attributes ~r/^((?:[pdqs]|h[0-7])?)((?:[\.\#][a-zA-Z0-9_\-]+)+)?\:/
  @reg_amorce_et_texte   ~r/#{Regex.source(@reg_amorce_attributes)}(.+)$/

  @doc """
  Construit le contenu, en se servant si nécessaire des options (et 
  des métadonnées qui ont été ajoutées)

  ## Examples

    iex> build_as_html("h1:Un titre de niveau 1\\nh2:Un titre de niveau 2")
    ~s(<h1>Un titre de niveau 1</h1>\\n<h2>Un titre de niveau 2</h2>)

    # Défaut
    iex> build_as_html("p:Un paragraphe\\nd:Un divide\\nq:Une citation\\ns:Une section\\n:Un par défaut")
    ~s(<p>Un paragraphe</p>\\n<div>Un divide</div>\\n<quote>Une citation</quote>\\n<section>Une section</section>\\n<p>Un par défaut</p>)

  """
  def build_as_html(content, options \\ [options: []]) do

    default_tag = Keyword.get(options, :default_tag, "p")

    content
    |> treate_returns()
    |> String.split("\n")
    |> Enum.map(fn line ->
      line = String.trim(line)
      scanner = Regex.scan(@reg_amorce_et_texte, line)
      # |> IO.inspect(label: "Scan de ligne '#{line}'")
      cond do
        line == "" -> nil
        Enum.empty?(scanner) ->
          ~s(<#{default_tag}>#{treate_content(line, options)}</#{default_tag}>)
        true ->
          scanner = Enum.at(scanner, 0)
          [_tout, tag, selectors, content] = scanner
          tag = @smalltag_to_realtag[tag] || tag
          selectors = extract_attributes_from(selectors)
          tag = tag == "" && "p" || tag
          ~s(<#{tag}#{selectors}>#{treate_content(content, options)}</#{tag}>)
      end
    end)
    |> Enum.filter(fn fline -> not is_nil(fline) end)
    |> Enum.join("\n")

  end

  @doc """
  Traite du pur contenu
  """
  def treate_content(content, options) do
    content
    |> evaluate_helpers_functions(options)
    |> treate_alinks_in(options)
    |> treate_simple_formatages(options)
  end


  @reg_indented_format ~r/#{Regex.source(@reg_amorce_attributes)}(?:\n(?:\t|  )(?:.+))+/m

  @doc """
  Le texte du fichier peut contenir des formatages tels que :
  
    p.class:
      Ma ligne de texte
      Mon autre ligne de texte
  
  Il faut les reconstituer en :
  
    p.class: Ma ligne de texte
    p.class: Mon autre ligne de texte

  ## Examples

      iex> treate_returns("Sans balise")
      ~s(Sans balise)

      iex> treate_returns("p.class: Sans retour")
      ~s(p.class: Sans retour)

      iex> treate_returns("p.class:\\n  Une première ligne\\n  Une seconde ligne")
      ~s(p.class:Une première ligne\\np.class:Une seconde ligne)

      iex> treate_returns("p.css:\\n\\tTabulation avant ligne\\n\\tAutre ligne tabulée")
      ~s(p.css:Tabulation avant ligne\\np.css:Autre ligne tabulée)

      iex> treate_returns("p.css2:\\n\\tUne ligne tabulée\\n  Une ligne avec deux espaces.")
      ~s(p.css2:Une ligne tabulée\\np.css2:Une ligne avec deux espaces.)
  
  """
  def treate_returns(str) do
    Regex.replace(@reg_indented_format, str, fn tout, _ -> 
      [amorce | phrases] = 
      tout
      |> String.replace("\n  ", "\n\t")
      |> String.split("\n\t")
      # IO.inspect(amorce, label: "Amorce")
      # IO.inspect(phrases, label: "Tail")

      if String.match?(amorce, ~r/\.inline/) do
        amorce = String.replace(amorce, ".inline", "")
        # Traitement spécial de texte en ligne
        phrases = phrases
        |> Enum.map(fn p -> String.trim(p) end)
        |> Enum.join(" ")
        amorce <> phrases
      else
        # On ajoute l'amorce à tous les segments
        phrases
        |> Enum.map(fn seg -> amorce <> seg end)
        |> Enum.join("\n")
      end
    end)
    # |> IO.inspect(label: "Texte reformaté")
  end

  @doc """
  Traitement des liens comme dans markdown

  ## Examples

    iex> treate_alinks_in("[Titre](/to/route)", [])
    ~s(<a href="/to/route">Titre</a>)
    
  """
  @reg_alinks ~r/\[(.+)\]\((.+)\)/U
  def treate_alinks_in(content, _options) do
    Regex.replace(@reg_alinks, content, fn _, title, route ->
      ~s(<a href="#{route}">#{title}</a>)
    end)
  end

  @doc """
  Traitement des formatages simples hérités de markdown

  ## Examples

    iex> treate_simple_formatages("*italic*", [])
    "<em>italic</em>"

    iex> treate_simple_formatages("*ital* et *ic*", [])
    "<em>ital</em> et <em>ic</em>"

    iex> treate_simple_formatages("**gras**", [])
    "<strong>gras</strong>"

    iex> treate_simple_formatages("__underscore__", [])
    "<u>underscore</u>"

    iex> treate_simple_formatages("__under__ et __score__", [])
    "<u>under</u> et <u>score</u>"

    iex> treate_simple_formatages("1^er, 2^2 et 3^exposant.", [])
    "1<sup>er</sup>, 2<sup>2</sup> et 3<sup>exposant</sup>."

    iex> treate_simple_formatages("--del|ins--", [])
    "<del>del</del> <ins>ins</ins>"
    
    iex> treate_simple_formatages("--del--", [])
    "<del>del</del>"


  """
  @reg_bolds ~r/\*\*(.+)\*\*/U    ; @remp_bolds "<strong>\\1</strong>"
  @reg_italics ~r/\*(.+)\*/U      ; @remp_italics "<em>\\1</em>"
  @reg_under ~r/__(.+)__/U        ; @remp_under "<u>\\1</u>"
  @reg_superscript ~r/\^(.+)\b/U  ; @remp_superscript "<sup>\\1</sup>"
  @reg_del_ins ~r/\-\-(.+)\|(.+)\-\-/U ; @remp_del_ins "<del>\\1</del> <ins>\\2</ins>"
  @reg_del ~r/\-\-(.+)\-\-/U      ; @remp_del "<del>\\1</del>"
  
  def treate_simple_formatages(content, _options) do
    content
    |> replace_in_string(@reg_bolds       , @remp_bolds)
    |> replace_in_string(@reg_italics     , @remp_italics)
    |> replace_in_string(@reg_under       , @remp_under)
    |> replace_in_string(@reg_superscript , @remp_superscript)
    |> replace_in_string(@reg_del_ins     , @remp_del_ins)
    |> replace_in_string(@reg_del         , @remp_del)
  end
  defp replace_in_string(str, reg, remp) do
    Regex.replace(reg, str, remp)
  end


  defp extract_attributes_from(str) do
    attributes = 
    Regex.scan(~r/(?:([.#])([a-zA-Z0-9_\-]+))/, str) 
    |> Enum.reduce(%{id: nil, class: ""}, fn [_tout, type, selector], collector -> 
      [type, selector] 
      if type == "." do
        %{collector | class: collector.class <> selector <> " " }
      else
        %{collector | id: selector}
      end
    end)
    # |> IO.inspect(label: "Comme table")
    |> Enum.reduce("", fn {attr, value}, accu -> 
      if is_nil(value) or String.trim(value) == "" do
        accu
      else
        accu <> ~s( #{attr}="#{String.trim(value)}")
      end
    end)
    |> String.trim()
    if attributes == "" do
      ""
    else
      " #{attributes}"
    end
  end

end