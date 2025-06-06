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

    variables:      {Map} Table des variables utilisables dans le 
                    code.
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

    dest_folder:    Le nom du dossier, dans :folder, dans lequel il faut
                    exporter les fichiers générés. Ou le chemin 
                    absolu pour les mettre tout autre part
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
    phtml = phtml 
    |> Formatter.formate()
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après formate/1")
    |> Evaluator.evaluate_on_render() # ne touche pas :html si options.evaluation est False
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après evaluate_on_render/1")
    
    if Keyword.get(phtml.options, :to_data, false) do
      phtml
    else
      Map.get(phtml, :html)
    end
    # |> IO.inspect(label: "[to_html(%PhilHtml{})] Après get(:html)")
  end

  @doc """
  Fonction publique qui retourne les données c'est-à-dire la structure
  PhilHtml du fichier traité.

  Note : ajouter l'option no_file: true pour que le fichier destinatioin
  ne soit pas construit.
  """
  def to_data(foo, options) when is_binary(foo) and is_list(options) do
    to_html(foo, Keyword.merge(options, [
      to_data: true,
      force: true,
      no_header: true # on devrait pouvoir le changer
      ]) 
    )
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
  @params {Keyword} options Des options

  @return {HTMLString|Map} Le code à afficher ou la map phtml si options
          contient :to_data
  """
  def file_to_html(phtml)  when is_struct(phtml, PhilHtml) do
    options = phtml.options
    # IO.puts "-> PhilHtml.to_html(#{inspect phtml})"
    phtml = phtml
    |> treate_path()
    |> load_or_formate_path()
    # |> IO.inspect(label: "\n+++ phtml après load_or_formate")
    |> Evaluator.evaluate_on_render()
    # |> IO.inspect(label: "\n+++ phtml après evaluate_on_render")
    
    if options[:to_data] do
      phtml
    else
      Map.get(phtml, :html)
    end
  end

  def file_to_html(philpath) when is_binary(philpath) do
    file_to_html(philpath, [])
  end
  def file_to_html(philpath, options) when is_binary(philpath) do
    file_to_html(%PhilHtml{file: [src: philpath], options: options})
  end

  @doc """
  Retourne une liste contenant le chemin d'accès au fichier .phil, 
  le chemin d'accès au fichier destination (qui peut être dans un
  autre dossier et sous un autre nom) et un booléen indiquant s'il
  faut actualiser le fichier de destination.

  @return [:src, :dst, :update]
  """
  def treate_path(phtml) when is_struct(phtml, PhilHtml) do
    path = phtml.file[:src]
    fext    = Path.extname(path) # .phil (ou .html)
    faffix  = Path.basename(path, fext)
    folder  = Path.dirname(path)
    dest_folder = Keyword.get(phtml.options, :dest_folder, nil)
    dest_folder = if is_nil(dest_folder) do folder else
      if File.exists?(dest_folder) do
        dest_folder
      else
        Path.expand(Path.join([folder, dest_folder]))
      end
    end

    File.exists?(dest_folder) || raise("Destination Folder unfound: #{dest_folder}")
    
    src_path  = Path.join([folder, "#{faffix}.phil"])
    dest_name = Keyword.get(phtml.options, :dest_name, "#{faffix}.html")
    dst_path  = Path.join([dest_folder, dest_name])

    # Avec l'option :force, on doit forcer l'actualisation du fichier
    # donc le détruire s'il existe pour metre :update_required ci-
    # dessous à True
    if Keyword.get(phtml.options, :force, false) do
      File.exists?(dst_path) && File.rm(dst_path)
    end

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

  @doc """
  Fonction qui formate le texte d'un fichier (si ce formatage n'a pas
  encore été effectué) ou qui charge simplement sa version formatée
  """
  def load_or_formate_path(phtml) when is_struct(phtml, PhilHtml) do
    # IO.inspect(phtml, label: "Dans load_or_formate_path")
    if phtml.file[:require_update] do
      Formatter.formate_file(phtml)
    else 
      # On charge la version pré-formatée (qui devra encore être
      # évaluée au rendu)
      %{phtml | heex: File.read!(phtml.file[:dst])}
    end
  end

  defp mtime(path) do
    File.lstat!(path).mtime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end

end
