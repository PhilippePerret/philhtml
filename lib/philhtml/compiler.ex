defmodule PhilHtml.Compiler do
  @moduledoc """
  Typiquement, c'est le module qui s'occupe d'insérer les assets
  dans le code final.

  Ça doit se faire juste avant l'évaluation.
  """
  # require UsefullMethods
  import UsefullMethods

  @reg_pre_include ~r/^(?:pre\/)?inc(?:lude)?:(.+)$/Um
  # La première expression qui permet de retirer cette fonction qui
  # ne doit pas être interprété au cours du traitement comme une 
  # fonction.
  @reg_post_include ~r/^post\/inc(?:lude)?:(.+)$/Um
  @reg_post_include_end ~r/^<p>\$POSTINCLUDE\[(.+)\]\$<\/p>/Um

  @doc """
  Principalement, cette fonction permet d'inclure les textes à
  inclure définis par [pre/]include(...)
  """
  def pre_compile(phtml, :first) when is_struct(phtml, PhilHtml) do
    phtml
  end
  
  def pre_compile(phtml, :inclusions) when is_struct(phtml, PhilHtml) do
    phtml = 
    Regex.scan(@reg_pre_include, phtml.raw_content)
    |> Enum.reduce(phtml, fn [tout, relpath], phtml ->
      relpath = String.trim(relpath)
      fullpath = maybe_fullpath(relpath, phtml)
      rempl = cond do
        File.exists?(relpath) -> File.read!(relpath)
        fullpath && File.exists?(fullpath) -> File.read!(fullpath)
        true ->
          "p.error:** (ArgumentError) File `#{relpath}' (fullpath: #{inspect fullpath}) unfound."
        end
      %{phtml | raw_content: String.replace(phtml.raw_content, tout, rempl)}
    end)

    Regex.scan(@reg_post_include, phtml.raw_content)
    |> Enum.reduce(phtml, fn [tout, relpath], phtml ->
      rempl = "p:$POSTINCLUDE[#{relpath}]$"
      %{phtml | raw_content: String.replace(phtml.raw_content, tout, rempl)}
    end)
  end

  @reg_inline_comments ~r/^c\:.+$/Um
  @reg_bloc_comments  ~r/^c\:(\s+)?\n+.+\n\:c/Usm
  @reg_multi_returns ~r/\n\n\n+/ ; @remp_multi_returns "\n\n"

  # Suppression des commentaires. On peut les trouver en ligne :
  #   «««««««««««««««««««
  #   c: Un commentaire
  #   »»»»»»»»»»»»»»»»»»»
  # ou en bloc :
  #   «««««««««««««««««««
  #   c:
  #   Un bloc de commentaire dans le texte.
  #   :c
  #   »»»»»»»»»»»»»»»»»»»»
  # 
  def pre_compile(phtml, :remove_comments) do
    content = 
    phtml.raw_content
    |> String.replace(@reg_bloc_comments, "")
    |> String.replace(@reg_inline_comments, "")
    |> String.replace(@reg_multi_returns, @remp_multi_returns)
    %{phtml | raw_content: content}
  end
  
  defp maybe_fullpath(relpath, phtml) do
    if phtml.metadata[:folder] do
      Path.join([phtml.metadata[:folder], relpath])
    else 
      nil 
    end
  end

  @data_smart_phil_marks [
    blocs: [
      #     marks         remplacements
      {[":::", ":::"], ["code:", ":code"]},
      {["|||", "|||"], ["table:", ":table"]},
      {["...", "..."], ["raw:", ":raw"]},
      {["<<<", "<<<"], ["html:", ":html"]},
      {["<<<", ">>>"], ["html:", ":html"]},
      {["***", "***"], ["list:", ":list"]}
    ],
    inlines: []
  ]
  @doc """
  Remplace les marques intelligentes (simplifiées) par les vraies
  marque PhilHtml.
  Par exemple, `:::' sera remplacé par 'code: ... :code'

  ## Examples

    iex> treate_smart_phil_marks("Avant\\n:::\\nMon code\\n:::\\nAprès", [])
    ~s(Avant\\ncode:\\nMon code\\n:code\\nAprès)

    iex> treate_smart_phil_marks("Avant\\n:::javascript\\nCode javascript.\\nAutre ligne\\n:::", [])
    ~s(Avant\\ncode:javascript\\nCode javascript.\\nAutre ligne\\n:code)

    # Les tables
    iex> treate_smart_phil_marks("Avant\\n|||\\nCellule 1 | Cellule 2\\n|||\\nAprès", [])
    ~s(Avant\\ntable:\\nCellule 1 | Cellule 2\\n:table\\nAprès)

    # Les textes bruts
    iex> treate_smart_phil_marks("...\\nTexte brut\\n...", [])
    ~s(raw:\\nTexte brut\\n:raw)

    iex> treate_smart_phil_marks("... para meters\\nTexte brut\\n...", [])
    ~s(raw: para meters\\nTexte brut\\n:raw)

    # Les codes html
    iex> treate_smart_phil_marks("<<<\\n<code html>\\n<<<", [])
    ~s(html:\\n<code html>\\n:html)

    iex> treate_smart_phil_marks("<<< no_eval\\n<code html>\\n<<<", [])
    ~s(html: no_eval\\n<code html>\\n:html)

    iex> treate_smart_phil_marks("<<< no_eval\\n<code html>\\n>>>\\nAprès.", [])
    ~s(html: no_eval\\n<code html>\\n:html\\nAprès.)

  """
  # @param {PhilHtml} phtml Le constructeur courant. Il contient tout ce qu'il faut, même les options courantes ou les metadata du code.
  def treate_smart_phil_marks(%PhilHtml{} = phtml) do
    %{phtml | raw_content: treate_smart_phil_marks(phtml.raw_content, phtml.options)}
  end
  # @param {String} content Le contenu à traiter
  # @param {Keyword} options Les options (pourra contenir d'autres
  # marques customisées par le programmeur)
  def treate_smart_phil_marks(content, _options) when is_binary(content) do
    @data_smart_phil_marks[:blocs]
    |> Enum.reduce(content, fn {marks, remplacements}, content ->
      [starter, ender] = marks |> Enum.map(fn r -> Regex.escape(r) end)
      [rempl_starter, rempl_ender] = remplacements
      reg   = ~r/^#{starter}([^\n]*)(.+)\n#{ender}[ \t]*$/Ums
      remp  =  "#{rempl_starter}\\1\\2\n#{rempl_ender}"
      Regex.replace(reg, content, remp)
    end)
  end



  # ================================================================================
  # ================================================================================
  #                      P O S T - C O M P I L A T I O N
  # ================================================================================
  # ================================================================================


  @doc """
  Fonction principale qui ajoute s'il le faut les assets pour 
  produire le code final.
  """
  def post_compile(phtml) when is_struct(phtml, PhilHtml) do
    # IO.puts "\n-> post_compile"
    phtml
    |> traite_post_inclusion()
    |> traite_fichiers_css()
    |> traite_fichiers_javascript()
    |> put_in_full_code_or_meta_charset()
  end

  def traite_post_inclusion(phtml) do
    # IO.puts "\n-> traite_post_inclusion"
    Regex.scan(@reg_post_include_end, phtml.heex)
    |> Enum.reduce(phtml, fn [tout, relpath], phtml ->
      relpath = String.trim(relpath)
      rempl = 
        if File.exists?(relpath) do
          File.read!(relpath)
        else
          "** (ArgumentError) File `#{relpath}' unfound."
        end
      %{phtml | heex: String.replace(phtml.heex, tout, rempl)}
    end)

  end

  def traite_fichiers_css(phtml) do
    # IO.puts "\n-> traite_fichiers_css"
    if phtml.options[:no_header] do phtml else
      compile_css(phtml)
    end
  end
  def traite_fichiers_javascript(phtml) do
    if phtml.options[:no_header] do phtml else
      compile_javascript(phtml)
    end
  end

  defp common_css_path do
    Path.expand("#{__DIR__}../../../assets/css/common.css") |> Path.absname()
  end

  def compile_css(phtml) do
    meta = phtml.metadata
    css = [common_css_path()] ++ (Keyword.get(meta, :css, []))
    cond do
      is_binary(css)  -> [css]
      is_list(css)    -> Enum.reverse(css)
      true            -> :bad_css
    end |> Enum.reduce(phtml, fn css, phtml ->
      if css == :bad_css do
        add_error(phtml, "Invalid css: #{inspect css}")
      else
        %{phtml | heex: css_tag(css, phtml.options) <> phtml.heex}
      end
    end)
  end
  defp css_tag(relpath, options) do
    # IO.inspect(options, label: "\nOptions")
    if options[:compilation] === false do
      ~s(<link rel="stylesheet" href="#{relpath}" />\n)
    else
      # On rassemble tout le code
      path_in_assets = Path.join(["assets", "css", relpath])
      path = cond do
        File.exists?(relpath) -> relpath
        File.exists?(path_in_assets) -> path_in_assets
        is_nil(options[:folder]) -> ":unable-path:"
        true -> Path.expand(Path.join([options[:folder], relpath]))
      end
      if File.exists?(path) do
        ~s(<style type="text/css">) <> File.read!(path) <> "</style>"
      else
        relpath = Path.absname(relpath)
        ~s{<span class="error">** (ArgumentError) Unfound path: `#{relpath}'.</span>}
      end
    end
  end

  def compile_javascript(phtml) do
    meta = phtml.metadata
    if (js = Keyword.get(meta, :javascript, nil)) do
      cond do
        is_binary(js) -> [js]
        is_list(js)   -> js
        true          -> :bad_js
      end |> Enum.reduce(phtml, fn js, phtml ->
        if js == :bad_js do
          add_error(phtml, "Invalid value for js: #{inspect js}")
        else
          %{phtml | heex: phtml.heex <> js_tag(js, phtml.options)}
        end
      end)
    else phtml end
  end
  defp js_tag(relpath, options) do
    if options[:compilation] === false do
      ~s(\n<script defer src="#{relpath}"></script>)
    else
      # On rassemble tout le code
      path_in_assets = Path.join(["assets", "js", relpath])
      path = 
      cond do
        File.exists?(relpath) -> relpath
        File.exists?(path_in_assets) -> path_in_assets
        is_nil(options[:folder]) -> ":unable-path:"
        true -> Path.expand(Path.join([options[:folder], relpath]))
      end
      if File.exists?(path) do
        ~s(<script type="text/javascript">) <> File.read!(path) <> "</script>"
      else
        ~s{<span class="error">** (ArgumentError) Unfound path: `#{relpath}'.</span>}
      end
    end
  end



  @doc """
  Si les options le demandent, on produit un code complet, sinon on 
  ajoute juste une balise <meta charset="utf-8"> pour les caractè-
  res UTF8
  """
  def put_in_full_code_or_meta_charset(phtml) do
    if phtml.options[:no_header] do phtml else
      options = phtml.options
      options =
      if phtml.metadata[:full_code] do
        Keyword.put(options, :full_code, true)
      else options end
      heex =
      if options[:full_code] do
        """
        <html>
          <head>
            <meta charset="utf-8">
            <title>Titre à définir</title>
            </head>
          <body>
            #{phtml.heex}
          </body>
        </html>
        """
      else
        ~s(<meta charset="utf-8">\n) <> phtml.heex
      end
      %{phtml | heex: heex}
    end
  end
end