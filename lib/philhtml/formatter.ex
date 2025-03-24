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
    |> Compiler.pre_compile(:first)
    |> Parser.parse()
    # |> IO.inspect(label: "\n\n[formate(phtml)] APRÈS PARSE")
    |> formate_content()
    # |> IO.inspect(label: "\n\n[formate(phtml)] APRÈS formate_content")
    |> formate_toc_if_required()
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
    |> Enum.map(fn {type, section, raws_or_params} ->
      if type == :string do
        formate_section(type, %{content: section, raws: raws_or_params}, options)
      else
        formate_section(type, %{content: section, params: raws_or_params}, options)
      end
    end)
    |> Enum.join("\n")
    # |> IO.inspect(label: "Code après formate_section")
  end

  def formate_section(:raw, section, _options) do
    """
    #{section.content}
    """
  end

  # Formatage des tables
  def formate_section(:table, section, options) do
    # --- Préliminaires ---
    # - Paramètres -
    params = defaultize_params(:table, section.params)
    # - Attributs de la table -
    table_attrs = []
    |> add_attrs_is_defined(:id, params)
    |> add_attrs_is_defined(:class, params)
    |> Enum.join(" ")
    table_attrs = if table_attrs == "" do "" else " #{table_attrs}" end
    # --- Fabrication de la table ---
    table =
    String.split(section.content, "\n")
    |> Enum.map(fn tr -> 
      # Traitement des lignes (TR)
      String.split(tr, " | ")
      |> Enum.map(fn cell ->
        # Traitement des cellules (TD)
        cell
        |> treate_content(options)
        |> Str.wrap_into("<td>", "</td>")
        # |> IO.inspect(label: "CELL (finalisée)")
      end)
      |> Enum.join("")
      |> Str.wrap_into("<tr>", "</tr>")
    end)
    |> Enum.join("\n")
    |> add_column_settings(params)
    |> Str.wrap_into(~s(<table#{table_attrs}>\n), "\n</table>")

    table # @return
  end

  def formate_section(:code, section, _options) do
    # IO.inspect(section.params, label: "params Dans la section formate_section")
    collector = %{content: section.content, pre: "<pre>", code: "<code>", options: []}
    
    collector =
    String.split((section.params||""), " ")
    |> Enum.reduce(collector, fn option, collector ->
      # IO.inspect([option, content], label: "Option et content")
      case option do
      "remove_trailing_spaces" -> 
        content = String.replace(collector.content, ~r/^\W+/m, "")
        Map.merge(collector, %{content: content, options: collector.options ++ [option]})
      "as_doc" -> 
        Map.merge(collector, %{pre: ~s(<pre class="as_doc">), options: collector.options ++ [option]})
      "" -> collector
      end
    end)
    # |> IO.inspect(label: "Collector à la fin")
    """
    #{collector.pre}#{collector.code}
    #{collector.content}
    </code></pre>
    """
  end

  def formate_section(:html, section, options) do
    """
    #{treate_content(section.content, options)}
    """
  end

  def formate_section(:inline_code, section, _options) do
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
    |> replace_untouchable_codes(section.raws, options)
  end

  def replace_untouchable_codes(fcode, raws, _options) do
    # IO.inspect(fcode, label: "fcode donné à replace_untouchable_codes")
    # IO.inspect(raws, label: "raws donnés à replace_untouchable_codes")
    raws
    |> Enum.with_index()
    |> Enum.reduce(fcode, fn {raw, index}, fcode ->
      tag = "$PHILHTML#{index}$"
      case raw do
        {:code, rempl} -> String.replace(fcode, tag, ~s(<code>#{rempl}</code>))
        {:raw,  rempl} -> String.replace(fcode, tag, ~s(<pre><code>#{rempl}</code></pre>))
        {:heex, rempl} -> String.replace(fcode, tag, ~s(#{rempl}???))
      end
    end)
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



  @regex_guillemets ~r/(?:(^| | )")(.+)(?:"( | |$))/U ; @rempl_guillemets "\\1« \\2 »\\3"
  @regex_apostrophes ~r/'/U       ; @rempl_apostrophes "’"

  @doc """
  ## Traitement des guillemets droits

  ## Examples

    iex> formate_smart_guillemets(~s("bonjour"), [])
    "« bonjour »"

    iex> formate_smart_guillemets(~s("bonjour" et "re-bonjour"), [])
    "« bonjour » et « re-bonjour »"

    - On ne touche à rien si :smarties est à false
    iex> formate_smart_guillemets(~s("bonjour" et "re-bonjour"), [smarties: false])
    ~s("bonjour" et "re-bonjour")

    - On ne touche pas aux guillemets sans au moins un 'blanc' autour
    iex> formate_smart_guillemets(~s(<span class="height:12px;">solide</span>), [])
    ~s(<span class="height:12px;">solide</span>)

    - Avec des guillemets à transformer et d'autres non
    iex> formate_smart_guillemets(~s("bonjour" et >style="height:12x;">), [])
    ~s(« bonjour » et >style="height:12x;">)

    - Sauf si l'on n'a rien à corriger
    iex> formate_smart_guillemets(~s("bonjour" et >style="height:12x;">), [smarties: false])
    ~s("bonjour" et >style="height:12x;">)

  """
  def formate_smart_guillemets(string, options) do
    if options[:smarties] == false do
      string
    else
      string
      |> String.replace(@regex_guillemets, @rempl_guillemets)
      |> String.replace(@regex_apostrophes, @rempl_apostrophes)
    end
  end


  @doc """
  Pose des anti-wrappers sur les textes.

  ## Explication

    Même avec l'utilisation d'insécables ou de '&amp;nbsp;', des 
    signes (comme des ponctuations) peuvent se retrouver à la ligne.
    Pour empêcher ce comportement de façon définitive, on entoure les
    texte "insécables" de <nowrap>...</nowrap> qui est une balise 
    spéciale qui possède la propriété white-space à nowrap (d'où son
    nom).
    La méthode ci-dessous est chargée de cette opération.

    Noter qu'elle intervient après que les guillemets ont été (ou 
    non) remplacés par des chevrons. Elle s'assure également que 
    tous les insécables aient été placés (même avec les chevrons car
    ils ont pu être mis par l'utilisateur)

  ## Examples

    // Sans rien, ne change rien
    iex> pose_anti_wrappers("bonjour tout le monde")
    "bonjour tout le monde"

    // Mot unique, simple guillemets sans insécables
    iex> pose_anti_wrappers("« bonjour »")
    T.h "<nowrap>« bonjour »</nowrap>"
    
    // Deux mots, simple guillemets sans insécables
    iex> pose_anti_wrappers("« bonjour vous »")
    T.h "<nowrap>« bonjour</nowrap> <nowrap>vous »</nowrap>"

    // Plusieurs mots, simples guillemets sans insécables
    iex> pose_anti_wrappers("« bonjour à tous »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous »</nowrap>"

    iex> pose_anti_wrappers("bonjour !")
    T.h "<nowrap>bonjour !</nowrap>"

    iex> pose_anti_wrappers("bonjour !?!")
    T.h "<nowrap>bonjour !?!</nowrap>"

    iex> pose_anti_wrappers("bonjour vous !")
    T.h "bonjour <nowrap>vous !</nowrap>"

    iex> pose_anti_wrappers("bonjour vous !?")
    T.h "bonjour <nowrap>vous !?</nowrap>"

    iex> pose_anti_wrappers("« bonjour à tous ! »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous ! »</nowrap>"
    
    iex> pose_anti_wrappers("« bonjour à tous !?! »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous !?! »</nowrap>"
    
    iex> pose_anti_wrappers("« bonjour à tous » !")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous » !</nowrap>"

  """

  # Pour insécables simples manquantes
  @regex_req_insec_before_ponct ~r/ ([!?:;])/
  @rempl_req_insec_before_poncts " \\1"
  # Pour insécables manquantes entre tirets (penser qu'il peut y en 
  # avoir quand même une de placée, d'où l'utilisation de [  ] au 
  # lieu de l'espace seule)
  @regex_req_insec_in_cont ~r/([—–«])[  ](.+)[  ]([»—–])/Uu
  @rempl_req_insec_in_cont "\\1 \\2 \\3"
  # Le cas le plus complexe, où l'on peut avoir guillemets + tirets +
  # ponctuations doubles, dans tous les sens, c'est-à-dire aussi bien :
  #   — « bonjour à tous » ! —
  #   — « bonjour à tous » — !
  #   « — bonjour à tous » ! —  -- fautif, quand même
  #   « bonjour — à — tous ! »
  #   « bonjour — à tous — » !
  # Le seul cas qu'on envisage pas ici, c'est le cas de chevrons 
  # imbriqués dans des chevrons, qui est une faute.
  @regex_insecable_guils ~r/([—–«] )?([—–«] )(.+?)( [—–!?:;»]+)( [—–!?:;»]+)?( [—–!?:;»]+)?/u
  @regex_insecable_tirets ~r/([—–])[  ](.+)[  ]([—–])/Uu
  @regex_insecable_ponct ~r/([^ ]+) ([!?:;]+?)/Uu   ; @rempl_insecable_ponct "<nowrap>\\1&nbsp;\\2</nowrap>"
  @regex_inner_tag ~r/<(.+)>/U
  def pose_anti_wrappers(string, options \\ []) do
    string
    # On doit commencer par protéger toutes les espaces à l'intérieur
    # des balises
    |> string_replace(@regex_inner_tag, &antiwrappers_protect_space_in_tag/2, options)
    # Ensuite, on peut mettre des espaces insécables là où ils 
    # manquent
    |> String.replace(@regex_req_insec_before_ponct, @rempl_req_insec_before_poncts)
    |> String.replace(@regex_req_insec_in_cont, @rempl_req_insec_in_cont)
    # Ensuite on traite tous les cas d'insécables imbriqués
    |> string_replace(@regex_insecable_guils, &antiwrappers_guils_et_autres/7, options)
    # |> string_replace(@regex_insecable_guils, options)
    |> string_replace(@regex_insecable_tirets, options)
    |> String.replace(@regex_insecable_ponct, @rempl_insecable_ponct)
    # On remet les espaces à l'intérieur des balises
    |> String.replace("ESP_PSE", " ")
  end


  defp antiwrappers_protect_space_in_tag(_tout, inner_tag) do
    String.replace(inner_tag, " ", "ESP_PSE")
  end

  defp antiwrappers_guils_et_autres(tout, arg1, arg2, inner_guils, arg3, arg4, arg5) do
    # Le principe simple est le suivant : si +inner_guils+ contient 
    # un seul mot, on met le nowrap autour de tout, alors que s'il y
    # en a plusieurs, on ne prend que le dernier.
    inner_guils = String.split(inner_guils, " ")
    cond do
    Enum.count(inner_guils) == 1 -> 
      "<nowrap>#{tout}</nowrap>"
    Enum.count(inner_guils) == 2 -> 
      [first_mot, last_mot] = inner_guils
      "<nowrap>#{arg1}#{arg2}#{first_mot}</nowrap> <nowrap>#{last_mot}#{arg3}#{arg4}#{arg5}</nowrap>"
    true ->
      {first_mot, reste}  = List.pop_at(inner_guils, 0)
      {last_mot, reste}   = List.pop_at(reste, -1)
      reste = Enum.join(reste, " ")
      "<nowrap>#{arg1}#{arg2}#{first_mot}</nowrap> #{reste} <nowrap>#{last_mot}#{arg3}#{arg4}#{arg5}</nowrap>"
    end 
    |> String.replace(~r/ /, "&nbsp;")
  end


  @regex_exposants ~r/\^(.+)\b/Uu
  @regex_exposants_implicites1 ~r/([XV])(ème|eme|e)/Uu
  # Pas "C" qui traiterait "Ce" ni "M" qui traiterait "Me"
  @regex_exposants_implicites2 ~r/([0-9])(ère|ere|ème|eme|eres|er|re|e)/Uu
  @table_remplacement_exposants %{"ere" => "re", "ère" => "re", "eres" => "res", "eme" => "e", "ème" => "e"}
  
  @doc """
  Formatage des exposants dans le code +string+

  Note : La fonction corrige aussi les erreurs courantes.

  ## Examples

    iex> formate_exposants("1^er", [])
    ~s(1<sup>er</sup>)

    iex>formate_exposants("1^premier pour voir", [])
    ~s(1<sup>premier</sup> pour voir)

    iex>formate_exposants("1^ere", [])
    ~s(1<sup>re</sup>)

  """
  def formate_exposants(string, options) do
    new_string =
    Regex.replace(@regex_exposants, string, fn _tout, found ->
      found = if options[:correct] == false do
        found
      else
        @table_remplacement_exposants[found] || found
      end
      "<sup>#{found}</sup>"
    end)
  
    new_string =
      Regex.replace(@regex_exposants_implicites1, new_string, fn tout, avant, expose ->
        if options[:correct] == false do
          tout
        else
          expose = @table_remplacement_exposants[expose] || expose
          "#{avant}<sup>#{expose}</sup>"
        end
      end)

    Regex.replace(@regex_exposants_implicites2, new_string, fn tout, avant, expose ->
    if options[:correct] == false do
      tout
    else
      expose = @table_remplacement_exposants[expose] || expose
      "#{avant}<sup>#{expose}</sup>"
    end
  end)
  end

  # Méthode "détachée" permettant de placer les anti-wrappers sur les
  # String en tenant compte du nombre de mots.
  defp string_replace(string, regex, _options) do
    if String.match?(string, regex) do
      Regex.replace(regex, string, fn _tout, tbefore, content, tafter ->
        founds = String.split(content, " ")
        if Enum.count(founds) > 1 do
          # Contenu de plusieurs mot
          {first, founds} = List.pop_at(founds, 0)
          {last, founds}  = List.pop_at(founds, -1)
          reste = 
            if Enum.any?(founds) do
              " " <> Enum.join(founds, " ") <> " "
            else
              " "
            end
          "<nowrap>#{tbefore} #{first}</nowrap>#{reste}<nowrap>#{last} #{tafter}</nowrap>"
        else
          # Contenu d'un seul mot
          "<nowrap>#{tbefore} #{content} #{tafter}</nowrap>"
        end
      end)
    else
      string
    end
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

  # ================================================================
  #                T A B L E   D E S   M A T I È R E S
  # ================================================================

  @reg_tdm_mark ~r/PHILTOCPHIL/
  @reg_tdm_title ~r/<h([2-6])(.*)>(.+)<\/h\1>/U

  def formate_toc_if_required(phtml) do
    case String.match?(phtml.heex, @reg_tdm_mark) do
    true -> formate_toc(phtml)
    _ -> phtml
    end
  end

  def formate_toc(phtml) do
    phtml = %{phtml | tdm: []}

    phtml =
    Regex.scan(@reg_tdm_title, phtml.heex)
    |> Enum.with_index()
    |> Enum.reduce(phtml, fn {[tout, level, attrs, title], index}, phtml ->
      id = "tdm#{index}"
      # On ajoute ça à la table des matières
      tdm = phtml.tdm ++ [{String.to_integer(level), String.trim(title), id}]
      # Il faut ajouter un identifiant au titre s'il n'en a pas déjà,
      # sinon il faut le prendre
      rempl = ~s(<h#{level}#{attrs} id="#{id}">#{title}</h#{level}>)
      heex = String.replace(phtml.heex, tout, rempl, [global: false])
      Map.merge(phtml, %{heex: heex, tdm: tdm})
    end)

    IO.inspect(phtml.tdm, label: "Tous les titres")

    # Tous les titres de tdm sont dans phtml.tdm
    # On peut maintenant la mettre en forme
    ftdm = 
    Enum.map(phtml.tdm, fn {level, title, id} ->
      ~s(<div class="tdm"><a class="level-#{level}" href="##{id}">#{title}</a></div>)
    end)
    |> Enum.join("\n")
    ftdm = ~s(<section class="tdm-section">#{ftdm}</section>)
    |> IO.inspect(label: "TDM FINALE")

    %{phtml | heex: String.replace(phtml.heex, @reg_tdm_mark, ftdm)}
  end



  # ================================================================

  @doc """
  Traite du pur contenu. Tout ce qui est analysé comme du pur contenu 
  doit passer par ici. Mais attention : quand le contenu +content+ 
  vient par exemple de cellules de tableau, il peut contenir du code
  qui ne doit être évalué qu'au rendu (entre <:: ... ::>). Il faut
  donc le mettre de côté pour le traitement et le remettre ensuite.  

  @param {String} content Le texte à tranformer
  @param {Keyword} options Les options éventuelles

  @return {String} Le contenu modifié
  """
  def treate_content(content, options) do

    {content, codes_at_render} = Parser.extract_render_evaluations_from(content)
    
    content
    |> Evaluator.evaluate_on_compile(options)
    |> evaluate_helpers_functions(options)
    # À partir d'ici on formate/corrige vraiment le texte
    |> formate_smart_guillemets(options)
    |> pose_anti_wrappers(options)
    |> treate_alinks_in(options)
    |> treate_simple_formatages(options)
    |> formate_exposants(options)
    |> Parser.restore_render_evaluations(codes_at_render)
    # |> IO.inspect(label: "\n[Treate_content] Texte final")
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

    iex> treate_simple_formatages("***gras et italique*** et **gras**", [])
    ~s(<strong><em>gras et italique</em></strong> et <strong>gras</strong>)

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
  @reg_gras_ital ~r/\*\*\*(.+)\*\*\*/U  ; @rempl_gras_ital "<strong><em>\\1</em></strong>"
  @reg_bolds ~r/\*\*(.+)\*\*/U    ; @remp_bolds "<strong>\\1</strong>"
  @reg_italics ~r/\*(.+)\*/U      ; @remp_italics "<em>\\1</em>"
  @reg_under ~r/__(.+)__/U        ; @remp_under "<u>\\1</u>"
  @reg_superscript ~r/\^(.+)\b/U  ; @remp_superscript "<sup>\\1</sup>"
  @reg_del_ins ~r/\-\-(.+)\|(.+)\-\-/U ; @remp_del_ins "<del>\\1</del> <ins>\\2</ins>"
  @reg_del ~r/\-\-(.+)\-\-/U      ; @remp_del "<del>\\1</del>"
  
  def treate_simple_formatages(content, _options) do
    content
    |> replace_in_string(@reg_gras_ital   , @rempl_gras_ital)
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

  # Fonction traitant les anti-wrappers sur les strings avec guillemets
  # Elle permet d'utiliser Regex.replace dans un pipe de strings avec
  # la même utilisation d'une fonction de traitement (+callback)
  # 
  # @param {String} string La chaine à traiter
  # @param {Regex} regex L'expression régulière
  # @param {Function} callback La fonction de traitement
  # @param {Keyword} options Les options éventuelles.
  defp string_replace(string, regex, callback, _options) do
    Regex.replace(regex, string, callback)
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

  @doc """
  Reçoit les paramètres en string, tels que définis dans le texte
  (après une marque de formatage) et retourne une table.

  Les paramètres peuvent être de deux formes : 
  1) des mots seuls => options à True
  2) des définitions séparées par un signe "=". Les valeurs sont 
      évaluées à l'aide de StringTo.value

  ## Examples

    iex> params_string_to_params("option")
    [option: true]

    iex> params_string_to_params("var=valeur")
    [var: "valeur"]

    iex> params_string_to_params("var=val option var2=val2")
    [var2: "val2", option: true, var: "val"]

    iex> params_string_to_params("list=[1,2,3]")
    [list: [1, 2, 3]]

    iex> params_string_to_params("list=[100,auto]")
    [list: [100, "auto"]]

  @return {Map} La table des valeurs
  """
  def params_string_to_params(params, type \\ nil) do
    (params||"")
    |> String.split(" ")
    |> Enum.reduce([], fn param, kwords ->
      [key, value] = if String.match?(param, ~r/\=/) do
        [key, value] = String.split(param, "=")
        [key, StringTo.value(value)]
      else [param, true] end

      Keyword.put(kwords, String.to_atom(key), value)
    end)
  end

  @default_params_per_type [
    table: [id: nil, class: nil, col_widths: nil, col_classes: nil]
  ]
  def defaultize_params(type, params) do
    params = params_string_to_params(params, type)
    Keyword.merge(@default_params_per_type[type], params)
  end

  # Fonction qui reçoit les lignes (TR) de la table et qui, avant
  # que ne soit ajoutés les wrappers "<table>...</table>", définit
  # les colonnes si les paramètres le requiert.
  # 
  # @param {String} raws Le code des rangées (envoyé juste pour poursuivre le pipe)
  # @param {Map} params Paramètres de fabrication de la table (cf. la fonction ci-dessus)
  # 
  # @return {String} Le code HTML ajouté si nécessaire.
  defp add_column_settings(raws, params) do
    colgroup =
    if params[:col_widths] || params[:col_classes] do
      cols_count = Enum.count(params[:col_widths] || params[:col_classes])
      (0..(cols_count - 1)) 
      |> Enum.map(fn index ->
        col_attrs = []
        col_attrs = if is_nil(params[:col_widths]) do col_attrs else
          width = Enum.at(params[:col_widths], index)
          width = cond do
            is_integer(width) -> "#{width}px"
            is_binary(width)  -> width
            %{type: :pourcent} = width -> width.raw_value
          end
          col_attrs ++ [~s(width="#{width}")]
        end
        col_attrs = if is_nil(params[:col_classes]) do col_attrs else
          css = params[:col_classes] |> String.split(".") |> String.join(" ")
          col_attrs ++ [~s(class="#{css}")]
        end

        if Enum.count(col_attrs) == 0 do "" else
          " " <> Enum.join(col_attrs, " ")
        end

      end)
      |> Enum.map(fn col_attrs -> 
        ~s(<col#{col_attrs} />)
      end)
      |> Enum.join("\n")
      |> Str.wrap_into("<colgroup>\n", "\n</colgroup>\n")
    else
      "" # colgroup
    end <> raws
  end

  @doc """
  Ajoute à la liste d'attributs HTML +list+ la clé +key+ si elle est
  définie dans la table +table+

  @param {List} list La liste actuelle (vide en général)
  @param {Atom} key La clé (le nom de l'attribut) 
  @param {Map|Keyword} table La table de référence

  @return Si +table+ ne contient pas +key+, on renvoie la liste telle
  qu'elle est, sinon on ajoute ["<key>=\"<valeur key>\""]
  """
  def add_attrs_is_defined(list, key, table) do
    if is_nil(table[key]) do list else
      list ++ [~s(#{key}="#{table[key]}")]
    end
  end

end