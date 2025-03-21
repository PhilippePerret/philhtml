defmodule Safe.Type do
  @moduledoc """
  Pour s'assurer de la conformité d'une valeur.
  Le module a été initié pour s'assurer qu'une map ne possédait que
  des clés string
  """

  def ensure(map, :key_string) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn {k, v}, collector -> 
      cond do
      is_binary(k) -> Map.put(collector, k, v)
      is_atom(k) -> Map.put(collector, Atom.to_string(k), v)
      true -> raise "Type de clé inconnue… (#{inspect k})"
      end
    end)
  end

  def ensure(map, :key_atom) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn {k, v}, collector -> 
      cond do
      is_atom(k) -> Map.put(collector, k, v)
      is_binary(k) -> Map.put(collector, String.to_atom(k), v)
      true -> raise "Type de clé inconnue… (#{inspect k})"
      end
    end)
  end
  
end