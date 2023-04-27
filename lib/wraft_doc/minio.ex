defmodule WraftDoc.Minio do
  @moduledoc """
  All the MinIO related functionalities goes here
  """

  alias ExAws.Config
  alias ExAws.S3

  @default_expiry_time 60 * 5
  @minio_bucket System.get_env("MINIO_BUCKET")
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
    |> S3.upload(@minio_bucket, file_path)
    |> @ex_aws_module.request()
  end

  @doc """
  Streams all files in a given path/prefix and deletes them.
  """
  @spec delete_files(binary()) :: ex_aws_response()
  def delete_files(prefix) do
    stream =
      @minio_bucket
      |> S3.list_objects(prefix: prefix)
      |> @ex_aws_module.stream!()
      |> Stream.map(& &1.key)

    @minio_bucket
    |> S3.delete_all_objects(stream)
    |> @ex_aws_module.request()
  end

  @doc """
  Generate the presigned URL for a file.
  """
  @spec generate_url(binary()) :: binary()
  def generate_url(file_path, opts \\ []) do
    opts = put_in(opts[:expires_in], Keyword.get(opts, :expires_in, @default_expiry_time))
    config = Config.new(:s3, Application.get_all_env(:ex_aws))
    S3.presigned_url(config, :get, @minio_bucket, file_path, opts)
  end

  @doc """
  Lists all files in the given prefix/path, extracts only the keys out of
  the object and sorts them in the descending order.
  """
  @spec list_files(binary()) :: list()
  def list_files(prefix) do
    @minio_bucket
    |> S3.list_objects(prefix: prefix)
    |> @ex_aws_module.stream!()
    |> Stream.map(& &1.key)
    |> Enum.sort(:desc)
  end

  @spec copy_files(binary(), binary()) :: ex_aws_response()
  def copy_files(new_path, old_path) do
    @minio_bucket
    |> S3.put_object_copy(new_path, @minio_bucket, old_path)
    |> @ex_aws_module.request()
  end
end
