defmodule WraftDoc.Workers.PDFMetadataWorker do
  @moduledoc """
  Worker for processing PDF metadata extraction.
  """
  use Oban.Worker

  require Logger

  alias WraftDoc.PDFMetadata

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"file_path" => file_path, "organisation_id" => _organisation_id}}) do
    Logger.info("🔍 Starting PDF metadata extraction for file: #{file_path}")

    case PDFMetadata.extract_metadata(file_path) do
      {:ok, metadata} ->
        Logger.info("""
        ✨ PDF Metadata extracted successfully! 📄
        📌 Title: #{metadata.title || "N/A"}
        👤 Author: #{metadata.author || "N/A"}
        🛠️ Creator: #{metadata.creator || "N/A"}
        🏭 Producer: #{metadata.producer || "N/A"}
        📅 Created: #{metadata.creation_date || "N/A"}
        🔄 Modified: #{metadata.modification_date || "N/A"}
        """)

      # Here you would typically store the metadata in your database
      # For now, we're just logging it

      {:error, reason} ->
        Logger.error("❌ Failed to extract PDF metadata: #{reason}")
    end

    :ok
  end
end
