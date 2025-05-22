defmodule WraftDoc.Client.Minio do
  @moduledoc """
  All the MinIO related functionalities goes here
  """

  require Logger

  defmodule DownloadError do
    defexception message: "MinIO download error. File not found."
  end

  alias ExAws.Config
  alias ExAws.S3
  alias WraftDoc.Client.Minio.DownloadError

  @default_expiry_time 60 * 5
  @ex_aws_module Application.compile_env(:wraft_doc, [:test_module, :minio], ExAws)

  @typedoc """
  The responses of ExAws.request
  """
  @type ex_aws_response :: {:ok, any()} | {:error, any()}

  @doc """
  Uploads a given file to MinIO.
  """
  @spec upload_file(String.t()) :: ex_aws_response()
  def upload_file(file_path) do
    file_path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket(), file_path)
    |> @ex_aws_module.request()
    |> handle_upload_response()
  end

  defp handle_upload_response({:ok, result}), do: {:ok, result}

  defp handle_upload_response({:error, {:http_error, 413, _}}),
    do: {:error, "File too large for upload", 413}

  defp handle_upload_response({:error, _}), do: {:error, "File upload failed", 222}

  @doc """
  Streams all files in a given path/prefix and deletes them.
  """
  @spec delete_files(binary()) :: ex_aws_response()
  def delete_files(prefix) do
    stream =
      bucket()
      |> S3.list_objects(prefix: prefix)
      |> @ex_aws_module.stream!()
      |> Stream.map(& &1.key)

    bucket()
    |> S3.delete_all_objects(stream)
    |> @ex_aws_module.request()
  end

  @doc """
  Delete a file with a given path
  """
  @spec delete_file(binary()) :: ex_aws_response()
  def delete_file(prefix) do
    case list_objects(prefix) do
      {:ok, %{body: %{contents: [%{key: file_path}]}}} -> delete_object(file_path)
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Unknown error"}
    end
  end

  @doc """
  Downloads a file from the given path in MinIO.
  Returns the binary of the file, which can be written to a file.
  """
  @spec download(binary()) :: binary()
  # TODO - Write tests
  def download(path) do
    with {:ok, %{body: %{contents: [%{key: file_path}]}}} <- list_objects(path),
         [binary] <-
           bucket()
           |> S3.download_file(file_path, :memory)
           |> @ex_aws_module.stream!()
           |> Enum.to_list() do
      binary
    else
      _ ->
        Logger.error("MinIO download failed", path: path)
        raise DownloadError
    end
  end

  def list_objects(prefix) do
    bucket()
    |> S3.list_objects(prefix: prefix)
    |> @ex_aws_module.request()
  end

  defp delete_object(file_path) do
    bucket()
    |> S3.delete_object(file_path)
    |> @ex_aws_module.request()
  end

  @doc """
  Generate the presigned URL for a file.
  """
  @spec generate_url(binary()) :: binary()
  def generate_url(file_path, opts \\ []) do
    opts = put_in(opts[:expires_in], Keyword.get(opts, :expires_in, @default_expiry_time))
    config = Config.new(:s3, Application.get_all_env(:ex_aws))
    {:ok, url} = S3.presigned_url(config, :get, bucket(), file_path, opts)
    url
  end

  @doc """
  Lists all files in the given prefix/path, extracts only the keys out of
  the object and sorts them in the descending order.
  """
  @spec list_files(binary()) :: list()
  def list_files(prefix) do
    bucket()
    |> S3.list_objects(prefix: prefix)
    |> @ex_aws_module.stream!()
    |> Stream.map(& &1.key)
    |> Enum.sort(:desc)
  end

  @spec copy_files(binary(), binary()) :: ex_aws_response()
  def copy_files(new_path, old_path) do
    bucket = bucket()

    bucket
    |> S3.put_object_copy(new_path, bucket, old_path)
    |> @ex_aws_module.request()
  end

  @doc """
  Get the object from the given path. Will raise error if object not found.
  """
  @spec get_object(String.t()) :: binary()
  def get_object(file_path) do
    bucket()
    |> S3.get_object(file_path)
    |> @ex_aws_module.request()
    |> case do
      {:ok, %{body: binary}} ->
        binary

      _ ->
        raise DownloadError
    end
  end

  @doc """
  Check if a file exists in MinIO.
  """
  @spec file_exists?(binary()) :: boolean()
  def file_exists?(file_path) do
    bucket()
    |> S3.head_object(file_path)
    |> @ex_aws_module.request()
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp bucket, do: System.get_env("MINIO_BUCKET")
end
