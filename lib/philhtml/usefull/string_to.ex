defmodule StringTo do

  @reg_empty_list ~r/^\[[  \t]*\]$/
  @reg_inner_list ~r/^\[(.*)\]$/

  @reg_atom ~r/^\:[a-z_]+$/
  @reg_instring ~r/^"(.*)"$/
  @reg_integer ~r/^[0-9]+$/
  @reg_float ~r/^[0-9.]+$/
  @reg_const ~r/(true|false|nil)/
  @reg_pourcent_int ~r/^([0-9]+)\%$/
  @reg_pourcent_float ~r/^([0-9.]+)\%$/
  @reg_size_int ~r/^(?<value>[0-9]+)(?<unity>cm|px|pt|cm|mm|po|inc)$/
  @reg_size_float ~r/^(?<value>[0-9.]+)(?<unity>cm|px|pt|cm|mm|po|inc)$/
  @reg_range ~r/^[0-9]+\.\.[0-9]+$/

  @doc """
  Function qui reçoit un string quelconque et retourne la
  valeur correspondante en fonction de son contenu.

  Transformations possibles :

    // "string"      => "string" (pas de transformation)

    iex> StringTo.value("string")
    "string"

    // "200"         => 200
    iex> StringTo.value("200")
    200

    // "1..100"      => 1..100
    iex> StringTo.value("1..100")
    1..100

    // "20.0"        => 20.0
    iex> StringTo.value("20.0")
    20.0

    // "true"        => true
    iex> StringTo.value("true")
    true

    // "false"       => false
    iex> StringTo.value("false")
    false

    // "nil"         => nil
    iex> StringTo.value("nil")
    nil

    // "[<valeurs>]" => [<valeurs>] si possible
    iex> StringTo.value("[un, deux, trois]")
    ["un", "deux", "trois"]

    // "[<valeurs>]" => [<valeurs>] avec valeurs spéciales
    iex> StringTo.value("[1, 1.2, true, nil]")
    [1, 1.2, true, nil]

    // "50%" => %{type: :pourcent, value: 50}
    iex> StringTo.value("50%")
    %{type: :pourcent, value: 50, raw_value: "50%"}

    // "50.2cm"      => %{type: :size, value: 50.2, unity: "cm"}
    // Ou autres unités : "po", "inc", "mm", "px"
    iex> StringTo.value("50.2cm")
    %{type: :size, value: 50.2, unity: "cm", raw_value: "50.2cm"}
    iex> StringTo.value("10mm")
    %{type: :size, value: 10, unity: "mm", raw_value: "10mm"}

  """
  def value(x) when is_binary(x) do
    cond do
    x =~ @reg_inner_list -> list(x) # une liste reconnaissable
    x =~ @reg_atom      -> elem(Code.eval_string(x),0)  # :atom
    x =~ @reg_instring  -> elem(Code.eval_string(x),0)  # String
    x =~ @reg_range     -> elem(Code.eval_string(x),0)  # Range
    x =~ @reg_integer   -> String.to_integer(x)         # Integer
    x =~ @reg_float     -> String.to_float(x)           # Float
    x =~ @reg_const     -> elem(Code.eval_string(x),0)  # true, false,...
    xr = Regex.run(@reg_pourcent_int, x) -> 
      xr = xr |> Enum.at(1)
      %{type: :pourcent, value: String.to_integer(xr), raw_value: x}
    xr = Regex.run(@reg_pourcent_float, x) -> 
      xr = xr |> Enum.at(1)
      %{type: :pourcent, value: String.to_float(xr), raw_value: x}
    xr = Regex.named_captures(@reg_size_int, x) ->
      %{type: :size, value: String.to_integer(xr["value"]), unity: xr["unity"], raw_value: x}
    xr = Regex.named_captures(@reg_size_float, x) ->
      %{type: :size, value: String.to_float(xr["value"]), unity: xr["unity"], raw_value: x}
    true -> x # comme string ou autre
    end
  end
  def value(x), do: x


  @doc """
  Function qui reçoit un string est retourne une liste

  Le string peut être sous la forme :

    // "" ou "  "              => []
    iex> StringTo.list("")
    []
    iex> StringTo.list(" ")
    []

    // "Un, deux, trois" => ["Un", "deux", "trois"]
    iex> StringTo.list("Un, deux, trois")
    ["Un", "deux", "trois"]

    // "Un, 12, true" => ["Un", 12, true]
    iex> StringTo.list("Un, 12, true")
    ["Un", 12, true]

    // "Un, \"12\", \"true\""  => ["Un", "12", "true"]
    iex> StringTo.list("Un, \\"12\\", \\"true\\"")
    ["Un", "12", "true"]

    // "Un, :atom, "           => ["Un", :atom, ""]
    iex> StringTo.list("Un, :atom, ")
    ["Un", :atom, ""]

    // "[Un, deux, trois]" => ["Un", "deux", "trois"]
    iex> StringTo.list("[Un, deux, trois]")
    ["Un", "deux", "trois"]

    // "[Un, 1.2, false]" => ["Un", 1.2, false]
    iex> StringTo.list("[Un, 1.2, false]")
    ["Un", 1.2, false]

    // "Avec\, virgule, non"       => ["Avec, virgule", "non"]
    iex> StringTo.list("Avec\\\\, virgule, non")
    ["Avec, virgule", "non"]

    // "[Avec\, oui, non]" => ["Avec, oui", "non"]
    iex> StringTo.list("[Avec\\\\, oui, non]")
    ["Avec, oui", "non"]

    // "[\"Un\", \"deux\"]"    => ["Un", "deux"]
    iex> StringTo.list("[\\"Un\\", \\"deux\\"]")
    ["Un", "deux"]

    // "12, true, :atom, [1\,2\,3]" => [12, true, :atom, [1, 2, 3]]
    iex> StringTo.list("12, true, :atom, [1\\\\,2\\\\,3]")
    [12, true, :atom, [1, 2, 3]]

  """
  def list(str) when is_binary(str) do
    trimed_str = String.trim(str)
    if trimed_str == "" || trimed_str =~ @reg_empty_list do
      []
    else
      trimed_str
      |> String.replace(@reg_inner_list, "\\1")
      |> String.replace("\\,", "__VIRGU__")
      |> String.split(",")
      # - Une liste à partir d'ici -
      |> Enum.map(fn x -> 
          x
          |> String.replace("__VIRGU__", ",")
          |> String.trim()
          |> StringTo.value()
        end)
    end
  end

  def list(foo) do
    IO.inspect(foo, label: "\nN'est pas un string envoyé à StringTo.list")
    foo
  end

  @doc """
  Transformation d'un string en map

  ## WARNING

  Attention, cette fonction évalue le code fourni, donc elle ne doit
  surtout pas être utilisée pour du code venant de l'extérieur.

  ## Options

  * `keys: :atoms` pour transformer les clés en atoms.
  * `strict: true`. Par défaut, toutes les valeurs sont évaluées, 
    c'est-à-dire que les "true", par exemple, deviennent des true.
    Si `:strict` est à true (false par défaut), les valeurs ne sont
    pas touchées et "true" reste un string.


  ## Examples

    iex> StringTo.map(~s({"un": "format", "comme": "json"}))
    %{"un" => "format", "comme" => "json"}

    iex> StringTo.map(~s({"un": "format", "comme": "json"}), [keys: :atoms])
    %{un: "format", comme: "json"}

    iex> StringTo.map(~s(%{un: "format", comme: "map"}))
    %{un: "format", comme: "map"}

    iex> StringTo.map(~s(%{"un" => "format", "comme" => "unemap"}))
    %{"un" => "format", "comme" => "unemap"}

    iex> StringTo.map(~s(%{"un" => "format", "comme" => "unemap"}), [keys: :atoms])
    %{un: "format", comme: "unemap"}

    // En tranformant (interprétant) les valeurs
    iex> StringTo.map(~s({"un":"12", "deux":"true", "trois": ":atom"}))
    %{"un" => 12, "deux" => true, "trois" => :atom}

    // Sauf en mode :strict
    iex> StringTo.map(~s({"un":"12", "deux":"true", "trois": ":atom"}), [strict: true])
    %{"un" => "12", "deux" => "true", "trois" => ":atom"}

    // Chaine vide
    iex> StringTo.map("")
    nil

    // retourne la chaine en cas d'échec
    iex> StringTo.map("height:10px;")
    "height:10px;"

  """
  @reg_inner_json ~r/^\{.+\}$/
  @reg_inner_map  ~r/^\%\{.+\}$/
  def map(foo, options \\ []) do
    map = 
      cond do
        foo =~ @reg_inner_json -> JSON.decode!(foo)
        foo =~ @reg_inner_map  -> elem(Code.eval_string(foo), 0)
        foo == "" -> nil
        is_binary(foo) -> foo
        true -> raise "Impossible d'évaluer #{inspect foo} comme une Map. Doit être au format JSON ou Elixir."
      end
    cond do
    is_nil(map)     -> nil
    is_binary(map)  -> map
    true ->
      # Sauf si l'option :strict est à true, on évalue toujours les
      # valeurs
      map =
        if options[:strict] do
          map
        else
          Enum.reduce(map, %{}, fn {x, y}, accu -> 
            Map.put(accu, x, StringTo.value(y)) 
          end)
        end
      if options[:keys] == :atoms do
        Enum.reduce(map, %{}, fn {x, y}, accu ->
          Map.put(accu, String.to_atom(x), StringTo.value(y))
        end)
      else
        map
      end
    end
  end


  @doc """
  Effectue les transformations d'usage sur les strings pour en faire
  des chaines HTML valides.

  ## Doctests

    // Code (backsticks)
    iex> StringTo.html("`du code`")
    "<code>du code</code>"

    // Gras et italique
    iex> StringTo.html("***gras et italiques***")
    "<b><em>gras et italiques</em></b>"

    // Gras
    iex> StringTo.html("**du gras**")
    "<b>du gras</b>"

    // Italique
    iex> StringTo.html("*italique*")
    "<em>italique</em>"

    // Souligné
    iex> StringTo.html("__souligné__")
    "<u>souligné</u>"

    // Substitution (correction/remplacement) : --bad//good--
    iex> StringTo.html("--mauvais//remplacement--")
    "<del>mauvais</del> <ins>remplacement</ins>"

    // Barré
    iex> StringTo.html("--barré--")
    "<del>barré</del>"

    // Exposant
    iex> StringTo.html("2^e 1^er un^exposant")
    "2<sup>e</sup> 1<sup>er</sup> un<sup>exposant</sup>"

    // Guillemets
    iex> StringTo.html("\\"bonjour\\"")
    "« bonjour »"

    # Simples retours chariots
    iex> StringTo.html("Un \\\\n retour")
    "Un<br />retour"

    # Ligne (séparatrice)
    iex> StringTo.html("---")
    "<hr />"

    # Anti-wrappings
    iex> StringTo.html "bonjour !"
    "<nowrap>bonjour !</nowrap>"

  """
  # Ne pas oublier de mettre ici tous les "candidats", c'est-à-dire
  # tous les textes qui peuvent déclencher la correction.
  @reg_candidats_html ~r/[\`\*_\-\^\\\"\'\:\;\!\?]/

  # Expression régulière pour capturer les codes entre backsticks.
  # Note : on en profite pour remplacer les '<' par des '&lt;'.
  @reg_backsticks ~r/\`(.+)\`/U # ; @remp_backsticks "<code>\\1</code>"
  @reg_bold_ital ~r/\*\*\*(.+)\*\*\*/U; @remp_bold_ital "<b><em>\\1</em></b>"
  @reg_bold ~r/\*\*(.+)\*\*/U; @remp_bold "<b>\\1</b>"
  @reg_ital ~r/\*([^ ].+)\*/U; @remp_ital "<em>\\1</em>"
  @reg_underscore ~r/__(.+)__/U; @remp_underscore "<u>\\1</u>"
  @reg_substitute ~r/\-\-(.+)\/\/(.+)\-\-/U; @remp_substitute "<del>\\1</del> <ins>\\2</ins>"
  @reg_strike ~r/\-\-(.+)\-\-/U; @remp_strike "<del>\\1</del>"
  @reg_exposant ~r/\^(.+)(\W|$)/U; @remp_exposant "<sup>\\1</sup>\\2"
  @reg_guillemets ~r/"(.+)"/U; @remp_guillemets "« \\1 »"
  @reg_return ~r/( +)?\\n( +)?/; @remp_return "<br />"
  @reg_line ~r/(^|\r?\n)\-\-\-(\r?\n|$)/; @remp_line "\\1<hr />\\2"
  
  # Expression régulière pour capter les textes du style :
  #   ««« un mot ? »»»
  # et les transformer en :
  #   ««« un <nowrap>mot ?</nowrap>
  @reg_ponct_nowrap ~r/(^| )([^ ]+)([  ])([!?:;])/U ; @temp_ponct_nowrap "\\1<nowrap>\\2\\3\\4</nowrap>"
  # Notes
  #   Penser qu'on peut avoir des styles, par exemple <em>un mot</em> 
  #   et qu'on ne peut donc pas utiliser le \b
  #   Il existe une version beaucoup plus complexe, traitant aussi
  #   chevrons, les tirets, dans Pharkdown.
  #
  # Si le <nowrap> ne se révèle pas efficace, utiliser plutôt :
  # @reg_ponct_nowrap ~r/ ([^ ]+)([  ])([!?:;])/U ; @temp_ponct_nowrap " <span class=\"nowrap\">\\1\\2\\3</span>"

  def html(str, _options \\ %{}) do
    # Il faut que le string contienne un "candidat" pour que
    # la correction soit amorcée.
    if Regex.match?(@reg_candidats_html, str) do

      str = str
      |> String.replace(@reg_return, @remp_return)
      
      {str, protecteds} = get_all_protected_cars(str)
      
      str = str
      |> String.replace("'", "’")
      |> String.replace(@reg_guillemets, @remp_guillemets)
      |> String.replace(@reg_line, @remp_line)
      |> (&Regex.replace(@reg_backsticks, &1, fn _tout, code -> 
          "<code>" <> String.replace(code, "<", "&lt;") <> "</code>"
        end)).()
      |> String.replace(@reg_bold_ital, @remp_bold_ital)
      |> String.replace(@reg_bold, @remp_bold)
      |> String.replace(@reg_ital, @remp_ital)
      |> String.replace(@reg_underscore, @remp_underscore)
      |> String.replace(@reg_substitute, @remp_substitute)
      |> String.replace(@reg_strike, @remp_strike)
      |> String.replace(@reg_exposant, @remp_exposant)
      |> String.replace(@reg_ponct_nowrap, @temp_ponct_nowrap)

      if Enum.empty?(protecteds) do
        str
      else
        reput_all_protected_cars(str, protecteds)
      end
    else
      str
    end
  end

  defp get_all_protected_cars(str) do
    if not String.contains?(str, "\\") do
      # IO.puts "pas d'échappements dans #{inspect(str)}"
      {str, []}
    else
      # IO.puts "Il y a des échappements"
      collector =
        str
        |> String.split("\\") # => liste de tous les segments
        |> Enum.reduce(%{index: 0, remp: [], segments: []}, fn seg, coll ->
          case seg do
          "" ->
            Map.merge(coll, %{segments: coll.segments ++ [""]})
          _ ->
            protected = String.at(seg, 0)
            new_remp = "PPROTECTEDCARR#{coll.index}"
            new_segment = String.replace_leading(seg, protected, new_remp)
            Map.merge(coll, %{
              remp:     coll.remp ++ [protected],
              segments: coll.segments ++ [new_segment],
              index:    coll.index + 1
            })
          end
        end)

      {
        Enum.join(collector.segments, ""),
        collector.remp
      }
    end
  end

  defp reput_all_protected_cars(str, protecteds) do
    protecteds
    |> Enum.with_index(0)
    |> Enum.reduce(str, fn {protected, index}, str -> 
        String.replace(str, "PPROTECTEDCARR#{index}", protected)
      end)
  end


  @doc """
  Transforme un string de la forme ".class.class.class" en liste de
  classes CSS ou renvoie la chaine telle quelle.

  # Examples

    iex> StringTo.class_list(".css")
    ["css"]

    iex> StringTo.class_list(".css.class")
    ["css", "class"]

    iex> StringTo.class_list(".css .class")
    ["css", "class"]

    iex> StringTo.class_list("sans rien")
    nil
    
  """
  def class_list(foo, _options \\ []) do
    cond do
    String.match?(foo, ~r/\./) -> 
      foo
      |> String.split(".") 
      |> Enum.map(fn x -> String.trim(x) end)
      |> Enum.reject(fn x -> x == "" end)
    true -> nil
    end
  end
end