defmodule Mix.Tasks.Manual.Build do
  @moduledoc """
  Tâche pour fabriquer le manuel d'utilisation (qui est en PhilHtml)

  Pour la jouer :

    mix manual.build

  """
  use Mix.Task

  
  @shortdoc "Construit le manuel (à partir de .phil)"


  @impl Mix.Task
  def run(args) do
    lang = Enum.at(args, 0) || "fr"
    open_it = Enum.member?(args, "--open")
    Mix.shell().info("Fabrication du manuel-#{lang}, merci de patienter…")
    src = Path.absname("doc/manual/manual-#{lang}.phil")
    dst = Path.absname("doc/manual/manual-#{lang}.html")
    File.exists?(dst) && File.rm(dst)
    PhilHtml.to_html(src)
    if File.exists?(dst) do
      Mix.shell().info("Manuel fabriqué avec succès.")
      if open_it do
        System.cmd("open", ["-a", "Safari", ~s(#{dst})])
      else
        Mix.shell().info("(ajouter l'option `--open' pour l'ouvrir) après fabrication.")
      end
    else
      Mix.shell().error("** (Mix Phil) Pour une raison inconnue, le manuel n'a pas pu être construit.")
    end
  end

end

