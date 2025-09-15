defmodule WraftDoc.Utils.FileHelper do
  @moduledoc """
    Helper functions to files.
  """

  alias WraftDoc.Frames.WraftJson.Metadata, as: FrameMetadata
  alias WraftDoc.TemplateAssets.Metadata, as: TemplateAssetMetadata
  alias WraftDoc.Utils.FileValidator

  @required_frame_files ["wraft.json", "template.typst", "default.typst"]

  @doc """
  Extract file into path.
  """
  @spec extract_file(binary(), String.t()) :: String.t()
  def extract_file(file_binary, output_path) do
    {:ok, wraft_json} = get_wraft_json(file_binary)

    wraft_json
    |> get_allowed_files_from_wraft_json()
    |> Enum.each(fn allowed_file ->
      write_file(file_binary, allowed_file, output_path)
    end)

    Path.join(output_path, ".")
  end

  defp write_file(file_binary, allowed_file, output_path) do
    file_binary
    |> extract_file_content(allowed_file)
    |> case do
      {:ok, file_content} ->
        file_path = Path.join(output_path, allowed_file)

        file_path
        |> Path.dirname()
        |> File.mkdir()

        File.write!(file_path, file_content)

      _ ->
        nil
    end
  end

  @doc """
  Extract file content from file.
  """
  @spec extract_file_content(binary(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_file_content(file_binary, file_name) do
    {:ok, unfile} = Unzip.new(file_binary)
    unfile_stream = Unzip.file_stream!(unfile, file_name)

    file_content =
      unfile_stream
      |> Enum.into([], fn chunk -> chunk end)
      |> IO.iodata_to_binary()
      |> String.trim()

    case file_content do
      "" -> {:error, "File content is empty"}
      _ -> {:ok, file_content}
    end
  rescue
    e in Unzip.Error ->
      {:error, "Failed to extract file: #{Exception.message(e)}"}
  end

  @doc """
  Extract wraft_json from file.
  """
  @spec get_wraft_json(binary()) :: {:ok, map()} | {:error, String.t()}
  def get_wraft_json(file_binary) do
    file_binary
    |> extract_file_content("wraft.json")
    |> case do
      {:ok, wraft_json} ->
        wraft_json
        |> Jason.decode!()
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e in Jason.DecodeError ->
      {:error, "Failed to decode wraft.json: #{Exception.message(e)}"}
  end

  @doc """
  Read file binary.
  """
  @spec read_file_contents(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def read_file_contents(file_path) do
    file_path
    |> File.read()
    |> case do
      {:ok, binary} ->
        {:ok, binary}

      _ ->
        {:error, "Invalid ZIP file."}
    end
  end

  @doc """
  Get file entries.
  """
  @spec get_file_entries(binary()) :: {:ok, list(map())} | {:error, String.t()}
  def get_file_entries(file_binary) do
    with {:ok, unfile} <- Unzip.new(file_binary),
         entries <- Unzip.list_entries(unfile) do
      {:ok, entries}
    else
      _ ->
        {:error, "Invalid ZIP entries."}
    end
  end

  @doc """
  Get allowed files from wraft
  """
  @spec get_allowed_files_from_wraft_json(map()) :: list(String.t())
  def get_allowed_files_from_wraft_json(%{
        "packageContents" => %{"rootFiles" => root_files, "assets" => assets, "fonts" => fonts}
      }) do
    Enum.flat_map([root_files, assets, fonts], &get_paths_from_section/1)
  end

  defp get_paths_from_section(section) when is_list(section),
    do: Enum.map(section, fn item -> item["path"] end)

  defp get_paths_from_section(_), do: []

  @doc """
  Validate frame.
  """
  @spec validate_frame_file(String.t()) :: :ok | {:error, String.t()}
  def validate_frame_file(%{path: file_path} = file) do
    with true <- frame_file?(file),
         {:ok, file_entries} <- FileValidator.get_file_entries(file_path),
         :ok <- validate_required_files(file_entries),
         {:ok, file_binary} <- read_file_contents(file_path),
         {:ok, wraft_json} <- get_wraft_json(file_binary),
         :ok <- WraftDoc.Frames.WraftJsonSchema.validate(wraft_json) do
      wraft_json
      |> get_allowed_files_from_wraft_json()
      |> validate_missing_files(file_entries)
    end
  end

  defp frame_file?(file) do
    file
    |> get_global_file_type()
    |> case do
      {:ok, "frame"} -> true
      {:ok, _} -> {:error, "File is not a frame file."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_required_files(file_entries) do
    @required_frame_files
    |> Enum.filter(fn req_file ->
      not Enum.any?(file_entries, fn entry -> entry.path == req_file end)
    end)
    |> case do
      [] ->
        :ok

      missing_files ->
        missing_files
        |> Enum.map(fn file ->
          %{
            type: "file_validation_error",
            message: "Required files are missing: #{file}"
          }
        end)
        |> then(&{:error, &1})
    end
  end

  defp validate_missing_files(allowed_files, file_entries) do
    entry_paths = Enum.map(file_entries, &Map.get(&1, :path))

    allowed_files
    |> Enum.filter(fn allowed_file ->
      !Enum.any?(entry_paths, fn entry_path -> entry_path == allowed_file end)
    end)
    |> case do
      [] ->
        :ok

      files ->
        files
        |> Enum.map(fn file ->
          %{
            type: "file_validation_error",
            message: "Missing file in zip: #{file}"
          }
        end)
        |> then(&{:error, &1})
    end
  end

  @doc """
  Get file size
  """
  @spec file_size(binary()) :: String.t()
  def file_size(file_binary), do: file_binary |> byte_size() |> Sizeable.filesize()

  @doc """
  Get file metadata.
  """
  @spec get_file_metadata(Plug.Upload.t()) ::
          {:ok, String.t()} | {:error, String.t() | Ecto.Changeset.t()}
  def get_file_metadata(%Plug.Upload{path: file_path}) do
    with {:ok, file_binary} <- read_file_contents(file_path),
         {:ok, wraft_json} <- get_wraft_json(file_binary),
         metadata when is_map(metadata) <- Map.get(wraft_json, "metadata"),
         :ok <- validate_metadata(metadata) do
      {:ok, metadata}
    else
      nil ->
        {:error, "Metadata is missing"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_metadata(metadata) do
    metadata
    |> Map.get("type")
    |> case do
      "frame" -> validate_with_schema(FrameMetadata, metadata)
      "template_asset" -> validate_with_schema(TemplateAssetMetadata, metadata)
      nil -> {:error, "Type is missing"}
      _unsupported_type -> {:error, "Unsupported metadata type"}
    end
  end

  defp validate_with_schema(schema_module, metadata) do
    metadata
    |> schema_module.changeset()
    |> case do
      %Ecto.Changeset{valid?: true} ->
        :ok

      changeset ->
        {:error, format_changeset_errors(changeset)}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} ->
      %{
        type: "metadata_validation_error",
        message: "#{field}: #{Enum.join(messages, ", ")}"
      }
    end)
  end

  @doc """
  Determines the global file type of the given file.
  """
  @spec get_global_file_type(Plug.Upload.t()) :: {:ok | :error, String.t()}
  def get_global_file_type(file) do
    file
    |> get_file_metadata()
    |> case do
      {:ok, %{"type" => type}} when type in ["frame", "template_asset"] ->
        {:ok, type}

      {:ok, %{"type" => _unsupported_type}} ->
        {:error, "Invalid global file type"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get file information.
  """
  @spec get_global_file_info(Plug.Upload.t()) :: map()
  def get_global_file_info(%{filename: filename, content_type: content_type, path: file_path}) do
    file_path
    |> get_files()
    |> case do
      {:ok, files} ->
        %{
          name: filename,
          type: content_type,
          size: file_path |> File.read!() |> file_size(),
          files: files
        }

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_files(file_path) do
    file_path
    |> File.read!()
    |> get_file_entries()
    |> case do
      {:ok, file_entries} ->
        file_entries
        |> Enum.filter(fn entry ->
          !String.ends_with?(entry.file_name, "/") and
            not String.match?(entry.file_name, ~r/^__MACOSX\//)
        end)
        |> Enum.map(fn entry ->
          entry.file_name
        end)
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  end
end
