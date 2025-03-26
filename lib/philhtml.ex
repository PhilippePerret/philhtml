defmodule PhilHtml do
  @moduledoc """
  Documentation for `PhilHtml`.
  """

  defstruct [
    file: [
      src: nil,         # Le fichier .phil
      dst: nil,         # Le fichier .html.heex
      require_update: false
      ],
    options: [compilation: false], 
    raw_content: nil, # Le code brut
    frontmatter: nil, # Le frontmatter
    raw_body:    nil, # Le code de corps brut
    content: nil,     # Le contenu pendant le travail
    heex:     nil,    # Le code formaté en HEEX
    html:     nil,    # Le code final évalué
    metadata: [],     # Les métadonnées
    tdm:      nil,    # Pour construire la table des matières
    errors: [] # Les erreurs rencontrées
  ]

  alias PhilHtml.{Formatter, Evaluator}

  @doc """
  @main (code fourni)

  Formatage du code fourni en argument (qui peut être le chemin
  d'accès à un fichier).

  @return {HTMLString} Le code formaté, évalué.
  """
  def to_html(foo, options) when is_binary(foo) do
    # IO.puts "-> to_html avec un binaire et des options"
    if File.exists?(foo) do
      file_to_html(foo, options)
    else
      to_html(%PhilHtml{raw_content: foo, options: options})
    end
  end

  def to_html(foo) when is_binary(foo) do
    # IO.puts "-> to_html avec un binaire sans option"
    to_html(foo, [])
  end
  def to_html(phtml) when is_struct(phtml, PhilHtml) do
    # IO.puts "-> to_html avec un phtml"
    phtml 
    |> Formatter.formate()
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après formate/1")
    |> Evaluator.evaluate_on_render()
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après evaluate_on_render/1")
    |> Map.get(:html)
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après get(:html)")
  end
  

  @doc """
  @main (avec un fichier)
  Convertit le path +phil_path+ en pur HTML et le retourne pour affichage.
  
  @params {String} philpath Le chemin d'accès, .phil ou .html
  @params {Wordlist} options Des options

  @return {HTMLString} Le code à afficher
  """
  def file_to_html(phtml)  when is_struct(phtml, PhilHtml) do
    # IO.puts "-> PhilHtml.to_html(#{inspect phtml})"
    phtml
    |> treate_path()
    |> load_or_formate_path()
    |> Evaluator.evaluate_on_render()
    |> Map.get(:html)
  end

  def file_to_html(philpath) when is_binary(philpath) do
    file_to_html(philpath, [])
  end
  def file_to_html(philpath, options) when is_binary(philpath) do
    file_to_html(%PhilHtml{file: [src: philpath], options: options})
  end

  @doc """

  @return [:src, :dst, :update]
  """
  def treate_path(phtml) when is_struct(phtml, PhilHtml) do
    path = phtml.file[:src]
    fext    = Path.extname(path) # .phil (ou .html)
    faffix  = Path.basename(path, fext)
    folder  = Path.dirname(path)

    src_path  = Path.join([folder, "#{faffix}.phil"])
    dst_path  = Path.join([folder, "#{faffix}.html"])

    src_exists = File.exists?(src_path)
    dst_exists = File.exists?(dst_path)

    if not(src_exists) and not(dst_exists), do: raise "unable to find phil source."

    dst_date = dst_exists && mtime(dst_path) || nil
    src_date = src_exists && mtime(src_path) || nil

    dfile = [
      src: src_path,
      dst: dst_path,
      require_update: not(dst_exists) or DateTime.after?(src_date, dst_date)
    ]
    %{phtml | file: dfile}
  end

  def load_or_formate_path(phtml) when is_struct(phtml, PhilHtml) do
    # IO.inspect(phtml, label: "Dans load_or_formate_path")
    if phtml.file[:require_update] do
      case Formatter.formate_file(phtml) do
      :ok -> true
      {:error, erreur} -> 
        %{ phtml | errors: phtml.errors ++ erreur}
        raise erreur # pour le moment
      end
    end
    %{ phtml | heex: File.read!(phtml.file[:dst]) }
  end


  defp mtime(path) do
    File.lstat!(path).mtime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end

end
