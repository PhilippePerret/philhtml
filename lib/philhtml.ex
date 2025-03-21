defmodule PhilHtml do
  @moduledoc """
  Documentation for `PhilHtml`.
  """

  alias PhilHtml.{Formatter, Evaluator}

  @doc """
  Convertit le path +phil_path+ en HTML

  ## Examples

  @params {String} philpath Le chemin d'accès, .phil ou .html
  @params {Wordlist} options Des options
  """
  def to_html(philpath, options) do
    philpath
    |> treate_path() # => [src: .phil path, dst: .html path, update: true/false]
    |> load_or_formate_path(options) # => Map contenant :html_code
    |> Evaluator.evaluate(options)
  end

  def treate_path(path) do
    fext    = Path.extname(path) # .phil ou .html
    faffix  = Path.basename(path, fext)
    folder  = Path.dirname(path)

    src_path  = Path.join([folder, "#{faffix}.phil"])
    dst_path  = Path.join([folder, "#{faffix}.html"])

    src_exists = File.exists?(src_path)
    dst_exists = File.exists?(dst_path)

    if not(src_exists) and not(dst_exists), do: raise "unable to find phil source."

    dst_date = dst_exists && mtime(dst_path) || nil
    src_date = src_exists && mtime(src_path) || nil
    [
      src: src_path,
      dst: dst_path,
      update: not(dst_exists) or DateTime.after?(src_date, dst_date)
    ]
  end

  defp mtime(path) do
    File.lstat!(path).mtime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end

  def load_or_formate_path(data_path, options) do
    if data_path[:update] do
      Formatter.formate_path(data_path)
    end
    %{html_code: File.read!(data_path[:dst])}
  end

end
