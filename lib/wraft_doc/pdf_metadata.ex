defmodule WraftDoc.PDFMetadata do
  @moduledoc """
  Module for extracting metadata from PDF files.
  """

  def extract_metadata(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        metadata = %{
          title: extract_title(content),
          author: extract_author(content),
          creator: extract_creator(content),
          producer: extract_producer(content),
          creation_date: extract_creation_date(content),
          modification_date: extract_modification_date(content)
        }

        {:ok, metadata}

      {:error, reason} ->
        {:error, "Failed to read PDF file: #{reason}"}
    end
  end

  defp extract_title(content) do
    case Regex.run(~r/\/Title\s*\((.*?)\)/, content) do
      [_, title] -> title
      _ -> nil
    end
  end

  defp extract_author(content) do
    case Regex.run(~r/\/Author\s*\((.*?)\)/, content) do
      [_, author] -> author
      _ -> nil
    end
  end

  defp extract_creator(content) do
    case Regex.run(~r/\/Creator\s*\((.*?)\)/, content) do
      [_, creator] -> creator
      _ -> nil
    end
  end

  defp extract_producer(content) do
    case Regex.run(~r/\/Producer\s*\((.*?)\)/, content) do
      [_, producer] -> producer
      _ -> nil
    end
  end

  defp extract_creation_date(content) do
    case Regex.run(~r/\/CreationDate\s*\((.*?)\)/, content) do
      [_, date] -> date
      _ -> nil
    end
  end

  defp extract_modification_date(content) do
    case Regex.run(~r/\/ModDate\s*\((.*?)\)/, content) do
      [_, date] -> date
      _ -> nil
    end
  end
end
