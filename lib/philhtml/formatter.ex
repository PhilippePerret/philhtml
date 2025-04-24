defmodule PhilHtml.Formatter do

  alias PhilHtml.{Parser, Evaluator, Compiler}

  @doc """
  @main

  @return {PhilHtml}
  @public
  """
  def formate(phtml) when is_struct(phtml, PhilHtml) do
    # IO.inspect(phtml.options, label: "[formate] phtml.options")
    phtml
    |> Compiler.pre_compile(:first)
    |> Compiler.pre_compile(:inclusions)
    |> Compiler.treate_smart_phil_marks()
    |> Parser.parse()
    # |> IO.inspect(label: "\n\n[formate(phtml)] APRÈS PARSE")
    |> formate_content()
    # |> IO.inspect(label: "\n\n[formate(phtml)] APRÈS formate_content")
    |> formate_toc_if_required()
    |> Compiler.post_compile()
  end

  # Cette fonction sert à formater complètement un simple string
  # qui peut contenir n'importe quoi, et notamment des blocs. Elle
  # a été affinée pour traiter le contenu des listes (dont les items
  # peuvent contenir n'importe quoi.)
  # Ajouter l'option [no_header: true] pour ne pas ajouter les
  # css/js et la balise méta du charset.
  def formate(philcode, options) when is_binary(philcode) do
    formate(%PhilHtml{raw_content: philcode, options: options})
  end
  
  @doc """
  Fonction de formatage principal quand un fichier est fourni.
  @return {PhilHtml} phtml La structure
  """
  def formate_file(phtml) when is_struct(phtml, PhilHtml) do
    # IO.inspect(phtml, label: "\n\n[formate_file] PHTML")
    phtml = %{phtml | raw_content: File.read!(phtml.file[:src])}
    phtml = formate(phtml)
    # |> IO.inspect(label: "Dans formate_file")
    no_evaluation = Keyword.get(phtml.options, :evaluation, true) === false
    code_final = 
      if no_evaluation do
        phtml.heex
      else
        phtml = Evaluator.evaluate_on_render(phtml)
        phtml.html
      end

    # IO.inspect(code_final, label: "\n\nCode final")

    if phtml.options[:no_file] do
      %{phtml | html: code_final}
    else
      case File.write(phtml.file[:dst], code_final) do
      :ok -> phtml
      {:error, erreur} -> 
        %{ phtml | errors: phtml.errors ++ erreur}
        raise erreur # pour le moment
      end
    end
  end

  @doc """
  Fonction principale qui formate tout le contenu et retourne le 
  code html (seuls subsiste les <% ... %> ou les <:: ... ::> qui 
  seront évalués à la volée)

  @return {HTMLString} Code html.heex de la page
  """
  def formate_content(phtml) do
    %{phtml | heex: do_formate_content(phtml)}
  end
  defp do_formate_content(phtml) do
    # - Tag par défaut (si non défini) -
    deftag = Keyword.get(phtml.metadata, :default_tag, phtml.options[:default_tag] || "p")
    options = Keyword.merge(phtml.options, [
      metadata: phtml.metadata,
      default_tag: deftag
    ])
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

  @doc """
  Ensemble de fonctions qui formatent les blocs (et les blocs :string
  qui sont les blocs par défaut contenant du texte)

  @param {Atom} Type de la section (:string, :raw, :table, etc)
  @param {Typlet} section Caractéristiques de la section, à savoir :content et :params
  @param {Keyword} options Les options à prendre en compte.
  """
  def formate_section(:string, section, options) do
    section.content
    |> treate_returns()
    |> String.split("\n")
    |> Enum.filter(fn line -> String.trim(line) != "" end)
    |> Enum.map(fn line ->
      treate_content(line, options) 
    end)
    |> Enum.join("\n")
    |> replace_untouchable_codes(section.raws, options)
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
    # - Options -
    # Pour les cellules de tableau, aucun wrapper par défaut n'est
    # ajouté (phil amorce).
    options = Keyword.put(options, :no_phil_amorce, true)
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

    # Finaliser le contenu
    final_content = 
    collector.content
    |> String.replace("<", "&lt;")

    # |> IO.inspect(label: "Collector à la fin")
    """
    #{collector.pre}#{collector.code}
    #{final_content}
    </code></pre>
    """
  end

  # Dans un bloc :html, on corrige tous les containers
  def formate_section(:html, section, options) do
    content = treate_content_into_html_content(section.content, options)
    """
    #{content}
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

  # Traitement d'un bloc list. C'est le format le plus compliqué dans
  # le sens où plusieurs blocs list peuvent être imbriqués l'un dans
  # l'autre (et même d'autres blocs d'autres types, même si ça n'est
  # pas le plus compliqué).
  # Pour repérer les différents blocs :list, on s'appuie sur l'inden-
  # tation
  def formate_section(:list, section, options) do
    # IO.inspect(section, label: "\nSECTION dans :list")

    type_list = String.match?((section.params||""), ~r/\bnumbered\b/) && "ol" || "ul"

    # Options formate s'il y a plusieurs paragraphes dans l'item
    opts_multi_lines = options
    |> Keyword.put(:default_tag, "div")
    |> Keyword.put(:no_header, true)
    # Options formate s'il y a un seul item dans l'item
    opts_item_simple = options
    |> Keyword.put(:no_header, true)
    |> Keyword.put(:no_phil_amorce, true)

    # Attributs à mettre dans la balise
    # On garder seulement les attr=value
    attrs = if is_nil(section.params) || section.params == "" do "" else
      section.params
      |> String.trim()
      |> String.split(" ")
      |> Enum.filter(fn seg ->
        Regex.match?(~r/=/, seg)
      end)
      |> Enum.map(fn seg ->
        [attr, value] = String.split(seg, "=")
        ~s(#{attr}="#{value}")
      end)
      |> Enum.join(" ")
      |> String.trim()
    end
    attrs = if attrs == "", do: "", else: " #{attrs}"

    section.content
    |> Str.wrap_into("\n", "")
    |> String.split("\n\* ")
    |> Enum.filter(fn li -> String.trim(li) != "" end)
    |> Enum.map(fn raw_li -> 

      # Ici, on est forcément sur un seul item de la liste, qui est
      # soit composé de plusieurs lignes (donc peut contenir un autre
      # bloc) soit composé d'une seule ligne
      multi_lines = String.trim(raw_li) =~ ~r/\n/

      # Les options de formatage (différentes en fonction de multi-
      # ligne ou ligne unique)
      opts_formate = if multi_lines do
        opts_multi_lines
      else opts_item_simple end

      # On part du principe que l'indentation d'une liste doit 
      # toujours être de 2 (une tabulation ou deux espaces) ou
      # peut-être aussi d'une valeur définissable par l'utilisateur.
      # Donc, ici, on peut prendre toutes les lignes à partir du 3e
      # caractère. Sauf pour la première ligne (contenant "* " au 
      # départ, qui a été retiré lors de la découpe)
      # IO.inspect(raw_li, label: "raw_li")
      
      scroped_li =
      if multi_lines do
        raw_li 
        |> String.split(~r/\n(\t|  )/)
        |> Enum.join("\n")
        # |> IO.inspect(label: "scroped_li")
      else raw_li end

      scroped_li
      # |> Str.sup_indent() # Je crois que ça casse toutes les imbrications des listes
      # |> IO.inspect(label: "LI désindenté")
      |> formate(opts_formate)
      # |> IO.inspect(label: "Retour de formate")
      |> Map.get(:heex)
      |> Str.wrap_into("<li>", "</li>")
    end)
    |> Enum.join("\n")
    |> Str.wrap_into("<#{type_list}#{attrs}>", "</#{type_list}>")
  end


  @reg_html_container ~r/<([a-z0-9]+)(.*)>(.+)<\/\1>/U

  def treate_content_into_html_content(content, options) do
    if Regex.match?(@reg_html_container, content) do
      # IO.inspect(content, label: "Contenu AVEC html")
      Regex.replace(@reg_html_container, content, fn _tout, tag, inner_tag, content ->
        "<#{tag}#{inner_tag}>" <> treate_content_into_html_content(content, options) <> "</#{tag}>"
      end)
    else
      # IO.inspect(content, label: "Contenu SANS html")
      treate_content(content, Keyword.put(options, :no_phil_amorce, true))
    end
  end


  def replace_untouchable_codes(fcode, raws, _options) do
    # IO.inspect(fcode, label: "fcode donné à replace_untouchable_codes")
    # IO.inspect(raws, label: "raws donnés à replace_untouchable_codes")
    raws
    |> Enum.with_index()
    |> Enum.reduce(fcode, fn {raw, index}, fcode ->
      tag = "LIHP#{index}LMTH"
      case raw do
        {:code, rempl} -> String.replace(fcode, tag, ~s(<code>#{rempl}</code>))
        {:raw,  rempl} -> String.replace(fcode, tag, ~s(<pre><code>#{rempl}</code></pre>))
        {:heex, rempl} -> String.replace(fcode, tag, ~s(#{rempl}???))
      end
    end)
  end


  @reg_helpers_functions ~r/\:([a-zA-Z0-9_]+)\((.*)\)/U
  @doc """
  NOTE 
  Avant, la fonction n'avait pas besoin d'être précédée de _
  mais ce principe posait trop de problème pour les textes 
  comme :
    Il ou ell est parti(e) en Normandie.
  Maintenant, si parti\1 est vraiment une fonction, on doit
  écrire :
    Il ou ell est :parti(e) en Normandie.
  NOTE
  Le Phil-Formateur part du principe que tout texte de la forme :
  '_fonc_Tion(p)' — c'est-à-dire un string avec des minuscules, des
  majuscules et des traits plats, suivi d'une parenthèse ouverte,
  des arguments et une parenthèse fermée — est une fonction définie
  dans un helper.

  ## Examples
      Note : les exemples utilise les helpers qui se trouvent dans le
      dossier /test/fixtures/helpers/
      
      # Fonction commun (dans PhilHtml.Helpers)
      iex> evaluate_helpers_functions("C'est mon :p(chemin/acces) pour venir.", [])
      ~s(C'est mon <span class="path">chemin/acces</span> pour venir.)

      # Fonction personnelle (dans module personnel)
      iex> evaluate_helpers_functions(":mafonction()", [helpers: [HelperDeTest]])
      ~s(Texte pour remplacer la fonction `mafonction/0')

      # Fonction inconnue
      iex> evaluate_helpers_functions(":mafonctioninexistante()", [helpers: [HelperDeTest]])
      ~s(<span class="error">Unknown function `mafonctioninexistante/0'</span>)
  """
  def evaluate_helpers_functions(code, options) do
    Regex.scan(@reg_helpers_functions, code)
    |> Enum.reduce(code, fn [tout, fn_name, fn_params], accu ->
      module_or_nil = Evaluator.module_helper_for?(fn_name, fn_params, options)
      # |> IO.inspect(label: "module_or_nil (fonction :#{fn_name})")
      # raise "pour voir module_or_nil"
      rempl =
      case module_or_nil do
        nil -> 
          arity = StringTo.list(fn_params) |> Enum.count()
          ~s(<span class="error">Unknown function `#{fn_name}/#{arity}'</span>)
        dmodule -> 
          apply(Evaluator, :evaluate_in, dmodule)
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
    iex> pose_balises_nowrap("bonjour tout le monde")
    "bonjour tout le monde"

    // Mot unique, simple guillemets sans insécables
    iex> pose_balises_nowrap("« bonjour »")
    T.h "<nowrap>« bonjour »</nowrap>"
    
    // Deux mots, simple guillemets sans insécables
    iex> pose_balises_nowrap("« bonjour vous »")
    T.h "<nowrap>« bonjour</nowrap> <nowrap>vous »</nowrap>"

    // Plusieurs mots, simples guillemets sans insécables
    iex> pose_balises_nowrap("« bonjour à tous »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous »</nowrap>"

    iex> pose_balises_nowrap("bonjour !")
    T.h "<nowrap>bonjour !</nowrap>"

    iex> pose_balises_nowrap("bonjour !?!")
    T.h "<nowrap>bonjour !?!</nowrap>"

    iex> pose_balises_nowrap("bonjour vous !")
    T.h "bonjour <nowrap>vous !</nowrap>"

    iex> pose_balises_nowrap("bonjour vous !?")
    T.h "bonjour <nowrap>vous !?</nowrap>"

    iex> pose_balises_nowrap("« bonjour à tous ! »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous ! »</nowrap>"
    
    iex> pose_balises_nowrap("« bonjour à tous !?! »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous !?! »</nowrap>"
    
    iex> pose_balises_nowrap("« bonjour à tous » !")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous » !</nowrap>"

    # Conserve les balises html existante
    
    iex> pose_balises_nowrap("<span>bonjour !</span>")
    T.h "<nowrap><span>bonjour !</span></nowrap>"

    iex> pose_balises_nowrap("<span>bonjour</span> !")
    T.h "<nowrap><span>bonjour</span> !</nowrap>"

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
  @regex_inner_tag ~r/(<.+>)/U
  # [N1] Pour pallier le problème de `<span>bonjour !</span>' trans-
  # formé en `<nowrap><span>bonjour !</nowrap></span>', je me sers de
  # ce hack. En fait, pour le faire proprement, il faudrait découper 
  # suivant les conteneurs et non conteneurs et les traiter séparé-
  # ment mais ça me semble un peu complexe pour le moment alors que
  # ce hack peut faire l'affaire.
  @regex_inversion ~r/<\/nowrap><\/([a-z]+)>/ ; @rempl_inversion "</\\1></nowrap>"

  @regex_in_container ~r/<([a-z]+)(.*)>(.+)<\/\\1>/U
  def pose_balises_nowrap(string, options \\ []) do
    # Pour éviter que :
    #   <span>bonjour !</span>"
    # … soit traité en :
    #   <nowrap><span>bonjour !</nowrap></span>
    # … on découpe le string selon ses balises de container s'il en 
    # contient
    # 
    if Regex.match?(@regex_in_container, string) do
      # Ça me semble trop complexe pour le moment, je préfère ajouter
      # le traitement des inversions
    end

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
    # On traite les inversions possibles (cf. [N1])
    |> String.replace(@regex_inversion, @rempl_inversion)
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

    # IO.inspect(phtml.tdm, label: "Tous les titres")

    # Tous les titres de tdm sont dans phtml.tdm
    # On peut maintenant la mettre en forme
    ftdm = 
    Enum.map(phtml.tdm, fn {level, title, id} ->
      ~s(<div class="tdm"><a class="level-#{level}" href="##{id}">#{title}</a></div>)
    end)
    |> Enum.join("\n")
    ftdm = ~s(<section class="tdm-section">#{ftdm}</section>)
    # |> IO.inspect(label: "TDM FINALE")

    %{phtml | heex: String.replace(phtml.heex, @reg_tdm_mark, ftdm)}
  end



  # ================================================================

  @doc """
  Traite du pur contenu. Tout ce qui est analysé comme du pur contenu 
  doit passer par ici.

  Les codes à évaluer au rendu (entre <:: ... ::>) sont retirés en
  début de traitement et remis à la fin.

  Les amorces Phil de paragraphe (<tag>#<id>.<class>: ...) sont 
  retirées au début du traitement et traités en fin de chaine quand
  tout a été traité.
  span.error:Mon erreur => <span class="error">Mon erreur</span>

  Notes
  -----
    [N1]  Si on met du code HTML avant, les '<' et '>' seront 
          supprimés (on perdra donc complètement le formatage en
          HTML).

  @param {String} content Le texte à tranformer peut-être multi-lignes.
  @param {Keyword} options Les options éventuelles
                  Les options importantes ici sont :
                  no_phil_amorce:    Si true, aucune amorce phil par défaut ne sera appliqué
                  Sera également ajouté au cours du processus :
                  protected_segs:    La table des segments protégés
  @return {String} Le contenu modifié
  """
  def treate_content(content, options) do
    # IO.inspect(content, label: "\n-> treate_content avec content")
    # IO.inspect(options, label: "[treate_content] OPTIONS")
    {content, codes_at_render} = Parser.extract_render_evaluations_from(content)
    {content, phil_amorce} = Parser.extract_phil_amorce(content, options)      
    
    {content, options} = 
      content
      |> Evaluator.evaluate_on_compile(options)
      |> evaluate_helpers_functions(options)
      |> met_de_cote_protected_segs(options)

    content
    # À partir d'ici on formate/corrige vraiment le texte
    |> formate_smart_guillemets(options)
    |> pose_balises_nowrap(options) # Attention : [N1]
    |> treate_alinks_in(options)
    |> treate_simple_formatages(options)
    |> formate_exposants(options)
    # |> IO.inspect(label: "Avant traitement des amorces phil (phil_amorce: #{inspect phil_amorce})")
    |> apply_phil_amorce(phil_amorce, options)
    # |> IO.inspect(label: "APRÈS traitement des amorces phil")
    |> restore_protected_segs(options)
    |> Parser.restore_render_evaluations(codes_at_render)
    # |> IO.inspect(label: "\n[Treate_content] Texte final")
  end

  @doc """
  Fonction qui met les segments textuels qui sont entre PROTECTEDPHHT
  et PHHTPROTECTED de côté pour ne pas les corriger et pouvoir les 
  remettre à la fin (avec restore_protected_segs/2).
  """
  @reg_protected_segs ~r/PROTECTEDPHHT(.+)PHHTPROTECTED/Um
  def met_de_cote_protected_segs(content, options) do
    protected_segs = 
      Regex.scan(@reg_protected_segs, content)
      |> Enum.reduce(%{segs: [], content: content}, fn [tout, seg], coll ->
        balise = "PTDSG#{Enum.count(coll.segs)}GSDTP"
        Map.merge(coll, %{
          content:  String.replace(coll.content, tout, balise),
          segs:     coll.segs ++ [seg]
        })
      end)
    
    options = Keyword.put(options, :protected_segs, protected_segs.segs)
    {protected_segs.content, options}
  end
  @doc """
  Remet en place les segments protégés après le traitement/formatage
  des textes.
  """
  def restore_protected_segs(content, options) do
    protected_segs = 
    options[:protected_segs]
    |> Enum.with_index()
    |> Enum.reduce(content, fn {seg, index}, str ->
      balise = "PTDSG#{index}GSDTP"
      String.replace(str, balise, seg)
    end)
  end

  @doc """
  Traite le contenu +content+ (un paragraphe) avec l'amorce phil
  +phil_amorce+ en respectant les options +options+

  # Examples

    iex> apply_phil_amorce("contenu", [tag: nil, id: nil, class: nil], [])
    "contenu"

    iex> apply_phil_amorce("contenu", nil, [])
    "contenu"

    iex> apply_phil_amorce("contenu", [tag: "p", id: "monp", class: nil], [])
    ~s(<p id="monp">contenu</p>)

  @param {String} content Un contenu de paragraphe entièrement mis en forme.
  @param {Keyword} phil_amorce L'amorce du paragraphe. Définit :
            :tag    {String} La balise à utiliser
            :id     {String} L'identifiant
            :class  {List} La liste des classes CSS
  """
  def apply_phil_amorce(content, phil_amorce, _options) do
    cond do
    is_nil(phil_amorce)       -> content
    is_nil(phil_amorce[:tag]) -> content
    true ->
      attrs = []
      attrs = if is_nil(phil_amorce[:id]) do attrs else
        attrs ++ [~s(id="#{phil_amorce[:id]}")]
      end
      attrs = if is_nil(phil_amorce[:class]) do attrs else
        attrs ++ [~s(class="#{phil_amorce[:class]|>Enum.join(" ")}")]
      end

      attrs = if attrs == [] do "" else " #{attrs |> Enum.join(" ")}" end

      "<#{phil_amorce[:tag]}#{attrs}>#{content}</#{phil_amorce[:tag]}>"
    end
  end

  @reg_indented_format ~r/#{Regex.source(Parser.reg_amorce_attributes())}(?:\n(?:\t|  )(?:.+))+/m

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

    iex> treate_simple_formatages("\\\\n", [])
    "<br/>"


  """
  @reg_gras_ital ~r/\*\*\*(.+)\*\*\*/U  ; @rempl_gras_ital "<strong><em>\\1</em></strong>"
  @reg_bolds ~r/\*\*(.+)\*\*/U    ; @remp_bolds "<strong>\\1</strong>"
  @reg_italics ~r/\*(.+)\*/U      ; @remp_italics "<em>\\1</em>"
  @reg_under ~r/__(.+)__/U        ; @remp_under "<u>\\1</u>"
  @reg_superscript ~r/\^(.+)\b/U  ; @remp_superscript "<sup>\\1</sup>"
  @reg_del_ins ~r/\-\-(.+)\|(.+)\-\-/U ; @remp_del_ins "<del>\\1</del> <ins>\\2</ins>"
  @reg_del ~r/\-\-(.+)\-\-/U      ; @remp_del "<del>\\1</del>"
  @reg_slash_n ~r/\\n/            ; @remp_slash_n "<br/>"
  
  def treate_simple_formatages(content, _options) do
    content
    |> replace_in_string(@reg_gras_ital   , @rempl_gras_ital)
    |> replace_in_string(@reg_bolds       , @remp_bolds)
    |> replace_in_string(@reg_italics     , @remp_italics)
    |> replace_in_string(@reg_under       , @remp_under)
    |> replace_in_string(@reg_superscript , @remp_superscript)
    |> replace_in_string(@reg_del_ins     , @remp_del_ins)
    |> replace_in_string(@reg_del         , @remp_del)
    |> replace_in_string(@reg_slash_n     , @remp_slash_n)
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
  def params_string_to_params(params, _type \\ nil) do
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
          css = params[:col_classes] |> String.split(".") |> Enum.join(" ")
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