defmodule PhilHtml do
  @moduledoc """
  Documentation for `PhilHtml`.

  DEUX UTILISATIONS
  -----------------
  Deux utilisations très distinctes de l'extension :

  Première : On donne du code ou le chemin d'accès à un fichier 
              qui le contient et on renvoie le code transformé.
  Deuxième : On se sert de to_html pour tenir à jour un fichier
              que l'application doit évaluer (en général un 
              fichier .html.heex). Dans ce cas, to_html ne fait
              qu'actualiser le fichier destination si c'est néces-
              saire
  Pour le moment, la seule manière de passer par la deuxième 
  utilisation consiste à mettre evaluation: false dans les options.

  OPTIONS
  -------
  Les options, envoyées en second argument des fonctions :to_html et
  :to_heex, peuvent définir :

    no_header:      Si True, l'entête CSS/JS ne sera pas ajoutée
                    Default: False
    dest_name:      Nom du fichier final s'il doit être différent de
                    <root>.html
    evaluation:     Si False, le code ne sera pas évalué. Les codes 
                    entre <:: ... ::> seront enroulés dans les 
                    <%= ... %>. C'est utile pour la deuxième utili-
                    sation de l'extension (cf. ci-dessus)
                    Default: True
    compilation:    Si True, on ajoute le code CSS/JS en dur dans le
                    code final du dossier. Sinon, on met un lien vers
                    le fichier.
                    Default: False
    folder:         Chemin d'accès au dossier de l'application, mais 
                    il est défini par PhilHtml, il ne doit pas être
                    défini manuellement.
  """

  defstruct [
    file: [
      src: nil,         # Le fichier .phil
      dst: nil,         # Le fichier .html.heex
      require_update:   false
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
  
  @param {String} foo Le code à interpréter
  @param {Keyword} options Cf. ci-dessus

  @return {HTMLString} Le code formaté, évalué.
  """
  def to_html(foo, options) when is_binary(foo) do
    # IO.puts "\n-> to_html avec un binaire et des options"
    if File.exists?(foo) do
      options = Keyword.put(options, :folder, Path.dirname(foo))
      # |> IO.inspect(label: "Options in to_thml")
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
    |> Evaluator.evaluate_on_render() # ne touche pas :html si options.evaluation est False
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après evaluate_on_render/1")
    |> Map.get(:html)
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après get(:html)")
  end

  @doc """
  Pour obtenir le code HEEX du fichier (qui doit donc être interprété
  après par l'application)

  ATTENTION : Dans le retour, les codes à évaluer au rendu sont
  laissés dans des <:: <code à évaluer> ::>
  Pour obtenir un "vrai" code heex, utiliser to_html/2 en indiquant
  en options evaluation: false
  """
  def to_heex(raw_code, options \\ []) when is_binary(raw_code) do
    %PhilHtml{raw_content: raw_code, options: options}
    |> Formatter.formate()
    |> Map.get(:heex)
  end

  @doc """
  @main (avec un fichier)
  Convertit le path +phil_path+ en pur HTML et le retourne pour affichage.
  
  @params {String} philpath Le chemin d'accès, .phil ou .html
  @params {Wordlist} options Des options

  @return {HTMLString} Le code à afficher
  """
  def file_to_html(phtml)  when is_struct(phtml, PhilHtml) do
    IO.puts "-> PhilHtml.to_html(#{inspect phtml})"
    phtml
    |> treate_path()
    |> load_or_formate_path()
    # |> IO.inspect(label: "\n+++ phtml après load_or_formate")
    |> Evaluator.evaluate_on_render()
    # |> IO.inspect(label: "\n+++ phtml après evaluate_on_render")
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
    dest_name = Keyword.get(phtml.options, :dest_name, "#{faffix}.html")
    dst_path  = Path.join([folder, dest_name])

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
    # |> IO.inspect(label: "dfile")
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
