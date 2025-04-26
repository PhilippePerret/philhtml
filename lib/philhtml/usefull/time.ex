defmodule PhilHtml.File do
  @moduledoc """
  version 0.2.0

  import PhilHtml.File, only: [<fonction>: <arity>, ...]
  """

  @doc """
  Retourne la date de modification du fichier de chemin d'accès
  +path+

  @param {String} path Chemin d'accès au fichier

  @return {NaiveDateTime} la date de dernière modification
  @return {Nil} nil si le fichier n'existe pas
  """
  def file_mtime(path) do
    if File.exists?(path) do
      File.stat!(path).mtime 
      |> NaiveDateTime.from_erl!()
    else
      nil
    end
  end

  @doc """
  @return True si le fichier +path1+ a été modifié après le fichier
  de chemin d'accès +path2+

  @param {String} path1 Chemin d'accès au fichier à estimer
  @param {String} path2 Chemin d'accès au fichier à comparer

  @return {Boolean} True si path1 est après path2
          Retourne False si un des deux fichiers n'exite pas
  """
  def after?(path1, path2) when is_binary(path1) and is_binary(path2) do
    if File.exists?(path1) and File.exists?(path2) do
      NaiveDateTime.after?(file_mtime(path1), file_mtime(path2))
    else
      false
    end
  end

end