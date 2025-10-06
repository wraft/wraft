defmodule Mix.Tasks.Wraft.Bucket do
  @moduledoc """
  Creates the default storage bucket if it doesn't exist.

  ## Examples

      $ mix wraft.bucket
  """

  @shortdoc "Creates default storage bucket"

  use Mix.Task
  require Logger

  alias WraftDoc.Minio.Utils

  @requirements ["app.start"]
  def run(_) do
    # Skip bucket operations in test environment
    if Mix.env() == :test do
      Logger.info("Skipping bucket operations in test environment")
    else
      bucket = System.get_env("MINIO_BUCKET", "wraft")
      Logger.info("Checking if bucket '#{bucket}' exists...")

      case Utils.bucket_exists?(bucket) do
        true ->
          Logger.info("Bucket '#{bucket}' already exists.")

        false ->
          Logger.info("Creating bucket '#{bucket}'...")

          case Utils.create_bucket(bucket) do
            {:ok, _} ->
              Logger.info("Bucket '#{bucket}' created successfully.")

            {:error, error} ->
              Logger.error("Failed to create bucket '#{bucket}': #{inspect(error)}")
              raise "Failed to create bucket '#{bucket}'"
          end
      end
    end
  end
end
