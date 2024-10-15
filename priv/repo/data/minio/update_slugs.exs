defmodule WraftDoc.Minio.UpdateSlugs do
  @moduledoc """
   Update changes in the slug files

    Script for updating the slug files. You can run it as:

     mix run priv/repo/data/minio/update_slugs.exs
  """

  require Logger
  alias WraftDoc.Minio.Utils

  wraft_bucket = System.get_env("MINIO_BUCKET")

  Logger.info("Update slugs in object storage")

  # Move slugs
  slugs_file_path = Path.join(File.cwd!(), "priv/slugs")
  Utils.upload_files(wraft_bucket, slugs_file_path, "public/slugs")

  Logger.info("Update slugs in object storage completed")
end
