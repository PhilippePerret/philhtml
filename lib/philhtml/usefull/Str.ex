defmodule Str do
  @moduledoc """
  Extension de la classe String
  """

  @doc """
  Entoure la chaine +string+ avec les balises définies.

  Cette fonction est surtout utile pour les pipes.

  ## Examples

    iex> Str.wrap_into("chaine", "AUT")
    "AUTchaineAUT"

    iex> Str.wrap_into("chaine", "BEF", "AFT")
    "BEFchaineAFT"

  @param {String} string La chaine à entourer
  @param {String} bef_str La chaine à mettre avant
  @param {String|nil} aft_str La chaine à mettre après. Si non, défini, on prend +bef_str

  @return {String} La chaine encadrée
  """
  def wrap_into(string, bef_str, aft_str \\ nil) do
    bef_str <> string <> (aft_str || bef_str)
  end

  @doc """
  Supprime l'indentation de toutes les lignes du contenu

  ## Examples

    iex> sup_indent("  une ligne")
    "une ligne"

    iex> sup_indent("\\tune ligne\\n\\tAutre ligne")
    "une ligne\\nAutre ligne"

    iex> sup_indent("  \\nUne ligne\\n   Autre ligne  \\n  Troisième ligne\\nQuatrième")
    "Une ligne\\nAutre ligne\\nTroisième ligne\\nQuatrième"

  """
  def sup_indent(content, options \\ []) do
    content
    |> String.trim()
    |> String.replace(~r/^[ \t ]+/m, "")
    |> String.replace(~r/[ \t ]+$/m, "")
  end


end