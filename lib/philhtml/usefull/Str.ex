defmodule Str do
  @moduledoc """
  Extension de la classe String
  """

  @doc """
  Entoure la chaine +string+ avec les balises définies.

  Cette fonction est surtout utile pour les pipes.

  ## Examples

    iex> Str.wrap_to("chaine", "AUT")
    "AUTchaineAUT"

    iex> Str.wrap_to("chaine", "BEF", "AFT")
    "BEFchaineAFT"

  @param {String} string La chaine à entourer
  @param {String} bef_str La chaine à mettre avant
  @param {String|nil} aft_str La chaine à mettre après. Si non, défini, on prend +bef_str

  @return {String} La chaine encadrée
  """
  def wrap_into(string, bef_str, aft_str \\ nil) do
    bef_str <> string <> (aft_str || bef_str)
  end


end