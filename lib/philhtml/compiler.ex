defmodule PhilHtml.Compiler do
  @moduledoc """
  Typiquement, c'est le module qui s'occupe d'insérer les assets
  dans le code final.

  Ça doit se faire juste avant l'évaluation.
  """
  # require PhilHtml.UsefullMethods
  import PhilHtml.UsefullMethods

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

  @doc """
  Fonction principale qui ajoute s'il le faut les assets pour 
  produire le code final.
  """
  def post_compile(phtml) when is_struct(phtml, PhilHtml) do
    phtml
    |> traite_post_inclusion()
    |> traite_fichiers_css()
    |> traite_fichiers_javascript()
    |> put_in_full_code_or_meta_charset()
  end

  def traite_post_inclusion(phtml) do
    Regex.scan(@reg_post_include_end, phtml.heex)
    |> Enum.reduce(phtml, fn [tout, relpath], phtml ->
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
    if is_nil(phtml.metadata[:css]) do phtml else
      compile_css(phtml)
    end
  end
  def traite_fichiers_javascript(phtml) do
    if is_nil(phtml.metadata[:javascript]) do phtml else
      compile_javascript(phtml)
    end
  end

  def compile_css(phtml) do
    meta = phtml.metadata
    if (css = Keyword.get(meta, :css, nil)) do
      cond do
        is_binary(css)  -> [css]
        is_list(css)    -> Enum.reverse(css)
        true            -> :bad_css
      end |> Enum.reduce(phtml, fn css, phtml ->
        if css == :bad_css do
          add_error(phtml, "Invalid css: #{inspect css}")
        else
          %{phtml | heex: css_tag(css) <> phtml.heex}
        end
      end)
    else phtml end
  end
  defp css_tag(relpath) do
    ~s(<link rel="stylesheet" href="#{relpath}" />\n)
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
          %{phtml | heex: phtml.heex <> js_tag(js)}
        end
      end)
    else phtml end
  end
  defp js_tag(relpath) do
    ~s(\n<script defer src="#{relpath}"></script>)
  end



  @doc """
  Si les options le demandent, on produit un code complet, sinon on 
  ajoute juste une balise <meta charset="utf-8"> pour les caractè-
  res UTF8
  """
  def put_in_full_code_or_meta_charset(phtml) do
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