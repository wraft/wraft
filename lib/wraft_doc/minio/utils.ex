defmodule WraftDoc.Minio.Utils do
  @moduledoc false

  import Ecto.Query
  require Logger
  alias ExAws.S3
  alias WraftDoc.Account.Profile
  alias WraftDoc.Assets.Asset
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo

  @ex_aws_module Application.compile_env(:wraft_doc, [:test_module, :minio], ExAws)

  defmodule DownloadError do
    defexception message: "MinIO download error. File not found."
  end

  def download_locally_and_upload(source_bucket, source_path, target_bucket, target_path) do
    # Download binary from source bucket
    binary = download(source_bucket, source_path)

    # Write to a local path
    local_file_path = Path.join(File.cwd!(), source_path)
    local_file_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(local_file_path, binary)

    # Upload path to target bucket
    if file_exists?(target_bucket, target_path) do
      Logger.info("File already exists in #{target_bucket}:#{target_path}")
    else
      Logger.info("Uploading #{source_bucket}:#{source_path} to #{target_bucket}:#{target_path}")

      upload_files(target_bucket, local_file_path, target_path)
    end

    # Remove folder from local path
    File.rm_rf!(source_path |> String.split("/") |> List.first())
  end

  def upload_default_public_files(bucket) do
    Logger.info("Uploading default public files to #{bucket}")

    # Move images
    images_file_path = Path.join(File.cwd!(), "priv/static/images")

    if !file_exists?(bucket, "public/images"),
      do: upload_files(bucket, images_file_path, "public/images")

    # Move slugs
    slugs_file_path = Path.join(File.cwd!(), "priv/slugs")

    if !file_exists?(bucket, "public/slugs"),
      do: upload_files(bucket, slugs_file_path, "public/slugs")

    # Wraft files , default layouts and fonts
    wraft_file_path = Path.join(File.cwd!(), "priv/wraft_files")

    if !file_exists?(bucket, "public/wraft_files"),
      do: upload_files(bucket, wraft_file_path, "public/wraft_files")

    Logger.info("Uploaded default public files to #{bucket}")
  end

  # Uploads all files in local folder to a remote path.
  def upload_files(bucket, source_path, target_path) do
    if File.dir?(source_path) do
      upload_directory(bucket, source_path, target_path)
    else
      source_path
      |> S3.Upload.stream_file()
      |> S3.upload(bucket, target_path)
      |> @ex_aws_module.request()
    end
  end

  defp upload_directory(bucket, source_dir, target_dir) do
    source_dir
    |> File.ls!()
    |> Enum.map(fn file ->
      source_path = Path.join(source_dir, file)
      target_path = Path.join(target_dir, file)
      upload_files(bucket, source_path, target_path)
    end)
  end

  # Format file path
  def format(file_path) do
    if white_space_present?(file_path) do
      replace_white_spaces_with_hyphen(file_path)
    else
      file_path
    end
  end

  defp white_space_present?(file_path) do
    file_path
    |> Path.basename()
    |> String.contains?(" ")
  end

  # Replace consequtive white spaces with hyphen
  defp replace_white_spaces_with_hyphen(file_path) do
    file_path
    |> Path.dirname()
    |> Path.join(
      file_path
      |> Path.basename()
      |> String.replace(~r/\s+/, "-")
    )
  end

  # Download file from MinIO
  def download(bucket, file_path) do
    with {:ok, %{body: %{contents: [%{key: file_path}]}}} <- list_objects(bucket, file_path),
         [binary] <-
           bucket
           |> S3.download_file(file_path, :memory)
           |> @ex_aws_module.stream!()
           |> Enum.to_list() do
      binary
    else
      _ ->
        Logger.error("MinIO download failed", path: file_path)
        DownloadError
    end
  end

  # List all files in a given path
  def list_files(bucket, prefix) do
    bucket
    |> S3.list_objects(prefix: prefix)
    |> @ex_aws_module.stream!()
    |> Stream.map(& &1.key)
    |> Enum.sort(:desc)
  end

  # Create a new bucket
  def create_bucket(bucket) do
    bucket
    |> S3.put_bucket("")
    |> @ex_aws_module.request()
  end

  # Copy files from source bucket to target bucket
  def copy_files(source_bucket, source_path, target_bucket, target_path) do
    if file_exists?(target_bucket, target_path) do
      Logger.info("File already exists. Skipping copy.")
      true
    else
      target_bucket
      |> S3.put_object_copy(target_path, source_bucket, source_path)
      |> @ex_aws_module.request()
      |> case do
        {:ok, %{status_code: 200}} -> true
        {:error, _reason} -> false
      end
    end
  end

  # Copy files within the same bucket
  def copy_files(bucket, source_path, target_path) do
    copy_files(bucket, source_path, bucket, target_path)
  end

  # Check if a file exists
  def file_exists?(bucket, file_path) do
    bucket
    |> S3.head_object(file_path)
    |> @ex_aws_module.request()
    |> case do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # Check if a bucket exists
  def bucket_exists?(bucket) do
    bucket
    |> S3.head_bucket()
    |> @ex_aws_module.request()
    |> case do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # List all files in a bucket
  def list_all_objects(bucket) do
    bucket
    |> S3.list_objects()
    |> @ex_aws_module.stream!()
    |> Enum.map(& &1.key)
  end

  # Delete all files in a bucket
  def delete_all_objects(objects, bucket) do
    objects
    |> Enum.chunk_every(1000)
    |> Enum.each(fn chunk ->
      bucket
      |> S3.delete_multiple_objects(chunk)
      |> @ex_aws_module.request!()
    end)
  end

  # Delete a bucket
  def delete_bucket(bucket) do
    bucket
    |> S3.delete_bucket()
    |> @ex_aws_module.request!()
  end

  # Delete a file
  def delete_file(bucket, prefix) do
    case list_objects(bucket, prefix) do
      {:ok, %{body: %{contents: [%{key: file_path}]}}} -> delete_object(bucket, file_path)
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Unknown error"}
    end
  end

  defp delete_object(bucket, file_path) do
    bucket
    |> S3.delete_object(file_path)
    |> @ex_aws_module.request()
  end

  defp list_objects(bucket, file_path) do
    bucket
    |> S3.list_objects(prefix: file_path)
    |> @ex_aws_module.request()
  end

  ######### Revamp File Structure ##########
  @doc """
  Revamp file structure
  """
  def revamp_file_structure(bucket, file_path) do
    # Logger.info("Revamping file structure for #{file_path}")

    # TODO:Add logic to handle public files

    cond do
      String.starts_with?(file_path, ["orphan_files/", "organisations/", "users/", "public/"]) ->
        Logger.error("No need to revamp target file path: #{file_path}")

      String.starts_with?(file_path, "uploads/contents/") ->
        revamp_instances(bucket, file_path)

      String.starts_with?(file_path, "uploads/avatars/") ->
        revamp_user_profile_images(bucket, file_path)

      String.starts_with?(file_path, "uploads/assets/") ->
        revamp_assets(bucket, file_path)

      String.starts_with?(file_path, "uploads/logos/") ->
        revamp_organisation_logos(bucket, file_path)

      String.starts_with?(file_path, "uploads/layout-screenshots/") ->
        revamp_layout_screenshots(bucket, file_path)

      String.starts_with?(file_path, "temp/pipe_builds/") ->
        revamp_pipeline_builds(bucket, file_path)

      true ->
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end

  @doc """
  Revamp pipeline builds
  """
  def revamp_pipeline_builds(bucket, file_path) do
    # Download binary from source bucket
    case download(bucket, file_path) do
      binary when is_binary(binary) ->
        # Write to a local path
        local_file_path = Path.join(File.cwd!(), file_path)
        local_dir = Path.dirname(local_file_path)
        File.mkdir_p!(local_dir)
        File.write!(local_file_path, binary)

        local_file_path
        |> String.to_charlist()
        |> :zip.list_dir()
        |> case do
          {:ok, [zip_comment: []]} ->
            Logger.error("No files in the zip: #{inspect(file_path)}")
            copy_files(bucket, file_path, "orphan_files/" <> file_path)
            delete_file(bucket, file_path)

          {:ok, file_list} ->
            instance_file_path = find_instance_file_path(file_list)

            instance_id = instance_file_path |> String.split("/") |> Enum.at(2)

            query_instances(bucket, file_path, instance_id)
        end

        # Remove folder from local path
        File.rm_rf!(file_path |> String.split("/") |> List.first())

      DownloadError ->
        Logger.error("Download failed for #{file_path}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end

  # Private
  defp query_instances(bucket, file_path, instance_id) do
    Instance
    |> where([i], i.instance_id == ^instance_id)
    |> Repo.all()
    |> case do
      # No instances found, move to zip file to orphan_files folder
      [] ->
        Logger.error("No instances found for instance id: #{instance_id}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)

      instances ->
        Logger.error("Multiple instances found for instance id: #{instance_id}")
        # One or more instances found, process them
        iterate_instances(bucket, file_path, instances)
    end
  end

  defp iterate_instances(bucket, file_path, instances) do
    Enum.each(instances, fn instance ->
      # Extract organisation id
      %{content_type: %ContentType{organisation_id: <<_::288>> = organisation_id}} =
        Repo.preload(instance, :content_type)

      copy_files(bucket, file_path, "organisations/#{organisation_id}/" <> file_path)
      delete_file(bucket, file_path)
    end)
  end

  defp find_instance_file_path(file_list) do
    Enum.find_value(file_list, fn
      {:zip_file, file_path, _info, _comment, _offset, _comp_size} -> to_string(file_path)
      _ -> nil
    end)
  end

  @doc """
  Revamp layout screenshots
  """
  def revamp_layout_screenshots(bucket, file_path) do
    with <<_::288>> = layout_id <- file_path |> String.split("/") |> Enum.at(2),
         %Layout{organisation_id: <<_::288>> = organisation_id} = _layout <-
           Repo.get(Layout, layout_id) do
      updated_path = String.replace(file_path, "uploads", "organisations/#{organisation_id}")
      copy_files(bucket, file_path, updated_path)
      delete_file(bucket, file_path)
    else
      _ ->
        Logger.error("Layout not found for layout screenshot file path: #{file_path}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end

  @doc """
  Revamp user profile images
  """
  def revamp_user_profile_images(bucket, file_path) do
    with <<_::288>> = profile_id <- file_path |> String.split("/") |> Enum.at(2),
         %Profile{user_id: user_id} = _layout <- Repo.get(Profile, profile_id) do
      copy_files(
        bucket,
        file_path,
        "users/#{user_id}/profile/#{Path.basename(file_path)}"
      )

      delete_file(bucket, file_path)
    else
      _ ->
        Logger.error("Profile not found for profile pic path: #{file_path}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end

  @doc """
  Revamp assets
  """
  def revamp_assets(bucket, file_path) do
    with <<_::288>> = asset_id <- file_path |> String.split("/") |> Enum.at(2),
         %Asset{organisation_id: <<_::288>> = organisation_id} = _asset <-
           Repo.get(Asset, asset_id) do
      updated_path = String.replace(file_path, "uploads", "organisations/#{organisation_id}")
      copy_files(bucket, file_path, updated_path)
      delete_file(bucket, file_path)
    else
      _ ->
        Logger.error("Asset not found for asset file path: #{file_path}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end

  @doc """
  Revamp organisation logos
  """
  def revamp_organisation_logos(bucket, file_path) do
    with <<_::288>> = organisation_id <- file_path |> String.split("/") |> Enum.at(2),
         %Organisation{id: organisation_id} = _organisation <-
           Repo.get(Organisation, organisation_id) do
      copy_files(
        bucket,
        file_path,
        "organisations/#{organisation_id}/logo/#{Path.basename(file_path)}"
      )

      delete_file(bucket, file_path)
    else
      _ ->
        Logger.error("Organisation not found for organisation_id file path: #{file_path}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end

  @doc """
  Revamp instances
  """
  def revamp_instances(bucket, file_path) do
    instance_id = file_path |> String.split("/") |> Enum.at(2)

    Instance
    |> where([i], i.instance_id == ^instance_id)
    |> Repo.all()
    |> case do
      # No instances found
      [] ->
        Logger.error("No instances found for instance id: #{instance_id}")
        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)

      instances ->
        Logger.info("Multiple instances found for instance id: #{instance_id}")
        # One or more instances found, process them
        Enum.each(instances, fn instance ->
          # Extract organisation id
          extract_organisation_id(bucket, instance, file_path)
        end)
    end
  end

  # Private
  defp extract_organisation_id(bucket, instance, file_path) do
    case Repo.preload(instance, :content_type) do
      %{content_type: %ContentType{organisation_id: <<_::288>> = organisation_id}} ->
        updated_path = String.replace(file_path, "uploads", "organisations/#{organisation_id}")

        copy_files(bucket, file_path, updated_path)
        delete_file(bucket, file_path)

      _ ->
        Logger.error("No organisation_id found for instance id: #{instance.instance_id}")

        copy_files(bucket, file_path, "orphan_files/" <> file_path)
        delete_file(bucket, file_path)
    end
  end
end
