defmodule PhilHtml.Compiler do
  @moduledoc """
  Typiquement, c'est le module qui s'occupe d'insérer les assets
  dans le code final.

  Ça doit se faire juste avant l'évaluation.
  """
  # require PhilHtml.UsefullMethods
  import PhilHtml.UsefullMethods

  @reg_pre_include ~r/^(?:pre\/)?include\((.+)\)/Um
  # La première expression qui permet de retirer cette fonction qui
  # ne doit pas être interprété au cours du traitement comme une 
  # fonction.
  @reg_post_include ~r/^post\/include\((.+)\)/Um
  @reg_post_include_end ~r/^<p>\$POSTINCLUDE\[(.+)\]\$<\/p>/Um

  @doc """
  Principalement, cette fonction permet d'inclure les textes à
  inclure définis par [pre/]include(...)
  """
  def pre_compile(phtml) when is_struct(phtml, PhilHtml) do
    phtml = 
    Regex.scan(@reg_pre_include, phtml.raw_content)
    |> Enum.reduce(phtml, fn [tout, relpath], phtml ->
      rempl = 
        if File.exists?(relpath) do
          File.read!(relpath)
        else
          "** (ArgumentError) File `#{relpath}' unfound."
        end
      %{phtml | raw_content: String.replace(phtml.raw_content, tout, rempl)}
    end)

    Regex.scan(@reg_post_include, phtml.raw_content)
    |> Enum.reduce(phtml, fn [tout, relpath], pthml ->
      IO.inspect(tout, label: "tout")
      rempl = "p:$POSTINCLUDE[#{relpath}]$"
      %{phtml | raw_content: String.replace(phtml.raw_content, tout, rempl)}
    end)
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
        true ->
          phtml = add_error(phtml, "Invalid type for css (#{css})")
          []
      end |> Enum.reduce(phtml, fn css, phtml ->
        %{phtml | heex: css_tag(css) <> phtml.heex}
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
        is_binary(js)  -> [js]
        is_list(js)    -> js
        true ->
          phtml = add_error(phtml, "Invalid type for js (#{js})")
          []
      end |> Enum.reduce(phtml, fn js, phtml ->
        %{phtml | heex: phtml.heex <> js_tag(js)}
      end)
    else phtml end
  end
  defp js_tag(relpath) do
    ~s(\n<script defer src="#{relpath}"></script>)
  end
end