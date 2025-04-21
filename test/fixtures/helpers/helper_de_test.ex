defmodule HelperDeTest do
  @moduledoc """

  Ce module est chargé au début des tests


  """

  def essai(str) do
    "La fonction essai retourne ce qu’elle a reçu, #{str}."
  end

  def mafonction() do
    ~s(Texte pour remplacer la fonction `mafonction/0')
  end

  def monhelper do
    "Retour de mon helper"
  end

  def app_name do
    "Mon application"
  end

  def parti(lettre) do
    "parti#{lettre}"
  end

  def mafun(prenom) do
    "Bonjour #{prenom}."
  end

end