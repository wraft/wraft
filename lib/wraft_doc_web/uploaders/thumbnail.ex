defmodule WraftDocWeb.Uploaders.Thumbnail do
  @moduledoc """
  Shared ImageMagick thumbnail settings for uploaders.

  Both Waffle's `transform/2` callback and the offline backfill task in
  `Mix.Tasks.Wraft.BackfillThumbnails` consume these values, so they stay
  byte-identical regardless of which path produced a given thumb.
  """

  @size "200x200"

  @doc "200x200 square crop, centered, lightly compressed."
  @spec convert_string() :: String.t()
  def convert_string,
    do: "-strip -thumbnail #{@size}^ -gravity center -extent #{@size} -quality 90"

  @doc "Same args as `convert_string/0`, but as a list for `System.cmd/2`."
  @spec convert_args() :: [String.t()]
  def convert_args,
    do: ~w(-strip -thumbnail) ++ ["#{@size}^"] ++ ~w(-gravity center -extent) ++ [@size] ++ ~w(-quality 90)
end
