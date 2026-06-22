defmodule Mix.Tasks.Wraft.BackfillThumbnails do
  @moduledoc """
  Generates the `:thumb` version for existing organisation logos and user
  profile pictures that were uploaded before the thumbnail version was added
  to `WraftDocWeb.LogoUploader` and `WraftDocWeb.PropicUploader`.

  For each record with an attachment, downloads the original from MinIO,
  resizes it to a 200x200 thumbnail using ImageMagick, and uploads it back to
  the path the uploader expects (`logo_thumb_<id>.<ext>` /
  `profilepic_thumb_<id>.<ext>`). Existing thumbnails are skipped.

  ## Examples

      $ mix wraft.backfill_thumbnails
      $ mix wraft.backfill_thumbnails --only logos
      $ mix wraft.backfill_thumbnails --only propics
      $ mix wraft.backfill_thumbnails --force          # regenerate even if present
      $ mix wraft.backfill_thumbnails --dry-run        # show planned work, no writes
  """

  @shortdoc "Backfill 200x200 thumbnails for existing logos and profile pics"

  use Mix.Task
  import Ecto.Query, only: [from: 2]
  require Logger

  alias WraftDoc.Account.Profile
  alias WraftDoc.Client.Minio
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo
  alias WraftDocWeb.Uploaders.Thumbnail

  @requirements ["app.start"]

  @batch_size 500

  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        switches: [only: :string, force: :boolean, dry_run: :boolean]
      )

    only = opts[:only]
    force? = opts[:force] == true
    dry_run? = opts[:dry_run] == true

    binary = locate_magick!()
    state = %{binary: binary, force?: force?, dry_run?: dry_run?, counts: counts()}

    state = if only in [nil, "logos"], do: backfill_org_logos(state), else: state
    state = if only in [nil, "propics"], do: backfill_profile_pics(state), else: state

    log_summary(state.counts)
  end

  # Each backfill loads only id + filename in @batch_size chunks so we never
  # hold a long-running transaction (the per-row work — MinIO GET + ImageMagick
  # + MinIO PUT — runs entirely outside the DB connection).
  defp backfill_org_logos(state) do
    Logger.info("Backfilling organisation logo thumbnails...")

    paginate(Organisation, [:id, :logo], state, &process_org_logo/2)
  end

  defp backfill_profile_pics(state) do
    Logger.info("Backfilling profile picture thumbnails...")

    paginate(Profile, [:id, :user_id, :profile_pic], state, &process_profile_pic/2)
  end

  defp paginate(schema, fields, state, fun) do
    Stream.unfold(nil, fn
      :done ->
        nil

      cursor ->
        rows = fetch_page(schema, fields, cursor)
        next = if length(rows) < @batch_size, do: :done, else: List.last(rows).id
        {rows, next}
    end)
    |> Stream.flat_map(& &1)
    |> Enum.reduce(state, fun)
  end

  defp fetch_page(schema, fields, nil) do
    Repo.all(from(r in schema, order_by: r.id, limit: @batch_size, select: ^fields))
  end

  defp fetch_page(schema, fields, last_id) do
    Repo.all(
      from(r in schema,
        where: r.id > ^last_id,
        order_by: r.id,
        limit: @batch_size,
        select: ^fields
      )
    )
  end

  defp process_org_logo(%{logo: %{file_name: name}} = org, state) when is_binary(name) do
    case Path.extname(name) do
      "" ->
        Logger.warning("Skip org=#{org.id}: logo file_name has no extension (#{inspect(name)})")
        bump(state, :skipped)

      ext ->
        original_key = "organisations/#{org.id}/logo/logo_#{org.id}#{ext}"
        thumb_key = "organisations/#{org.id}/logo/logo_thumb_#{org.id}#{ext}"
        process(state, original_key, thumb_key, "org=#{org.id}")
    end
  end

  defp process_org_logo(_, state), do: state

  defp process_profile_pic(%{profile_pic: %{file_name: name}, user_id: user_id} = profile, state)
       when is_binary(name) and is_binary(user_id) do
    case Path.extname(name) do
      "" ->
        Logger.warning(
          "Skip profile=#{profile.id}: profile_pic has no extension (#{inspect(name)})"
        )

        bump(state, :skipped)

      ext ->
        # PropicUploader's filename uses the scope's `.id` (the profile id),
        # while storage_dir uses `profile.user_id` — keep both in sync here.
        profile_id = String.replace(profile.id, ~r/\s+/, "-")
        original_key = "users/#{user_id}/profile/profilepic_#{profile_id}#{ext}"
        thumb_key = "users/#{user_id}/profile/profilepic_thumb_#{profile_id}#{ext}"
        process(state, original_key, thumb_key, "profile=#{profile.id}")
    end
  end

  defp process_profile_pic(_, state), do: state

  defp process(state, original_key, thumb_key, tag) do
    cond do
      not state.force? and Minio.file_exists?(thumb_key) ->
        Logger.info("Skip #{tag}: thumb already exists at #{thumb_key}")
        bump(state, :skipped)

      not Minio.file_exists?(original_key) ->
        Logger.warning("Skip #{tag}: original missing at #{original_key}")
        bump(state, :skipped)

      state.dry_run? ->
        Logger.info("[dry-run] Would generate #{tag} -> #{thumb_key}")
        bump(state, :would_generate)

      true ->
        case generate_and_upload(state.binary, original_key, thumb_key) do
          :ok ->
            Logger.info("Thumb generated for #{tag} -> #{thumb_key}")
            bump(state, :generated)

          {:error, reason} ->
            Logger.error("Failed #{tag}: #{inspect(reason)}")
            bump(state, :failed)
        end
    end
  end

  defp generate_and_upload(binary, original_key, thumb_key) do
    ext = Path.extname(thumb_key)
    src = tmp_path("wraft_thumb_src", ext)
    dst = tmp_path("wraft_thumb_dst", ext)
    content_type = MIME.from_path(thumb_key)

    try do
      with :ok <- File.write(src, Minio.get_object(original_key)),
           {_, 0} <-
             System.cmd(binary, [src | Thumbnail.convert_args()] ++ [dst], stderr_to_stdout: true),
           {:ok, body} <- File.read(dst),
           {:ok, _} <- Minio.put_object(thumb_key, body, content_type: content_type) do
        :ok
      else
        {output, code} when is_binary(output) -> {:error, {:convert_failed, code, output}}
        {:error, _} = err -> err
        other -> {:error, other}
      end
    rescue
      e -> {:error, Exception.message(e)}
    after
      File.rm(src)
      File.rm(dst)
    end
  end

  defp tmp_path(prefix, ext),
    do: Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}#{ext}")

  defp locate_magick! do
    case System.find_executable("magick") || System.find_executable("convert") do
      nil ->
        Mix.raise("""
        ImageMagick not found. Install ImageMagick 7 (`magick`) or 6 (`convert`)
        and ensure it is on PATH before running this task.
        """)

      path ->
        Logger.info("Using ImageMagick binary at #{path}")
        path
    end
  end

  defp counts,
    do: %{generated: 0, skipped: 0, failed: 0, would_generate: 0}

  defp bump(state, key),
    do: update_in(state, [:counts, key], &(&1 + 1))

  defp log_summary(%{generated: g, skipped: s, failed: f, would_generate: w}) do
    Logger.info("Backfill complete — generated=#{g} skipped=#{s} failed=#{f} would_generate=#{w}")
  end
end
