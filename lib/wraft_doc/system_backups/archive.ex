defmodule WraftDoc.SystemBackups.Archive do
  @moduledoc """
  Shared handling for uploaded Full backup archives — a zip (current) or tar
  (legacy) of `database.dump` + `bucket.tar` + `manifest.json`.

  Detection, validation, and extraction all go through the `@cmd_runner` seam
  so they're testable and behave identically whether they're called from the
  admin upload UI (validate) or the import worker (extract).
  """

  @cmd_runner Application.compile_env(
                :wraft_doc,
                [:test_module, :cmd_runner],
                WraftDoc.SystemBackups.CmdRunner.SystemCmd
              )

  @doc "True when the archive is a zip (leading `PK` magic; tar's magic is at byte 257)."
  def zip?(path) do
    case :file.open(String.to_charlist(path), [:read, :binary]) do
      {:ok, io} ->
        result = :file.read(io, 2)
        :file.close(io)
        result == {:ok, "PK"}

      _ ->
        false
    end
  end

  @doc """
  Validates that the archive is readable and contains a `database.dump` member,
  for fast synchronous feedback before enqueuing the import. Returns `:ok` or
  `{:error, message}`.
  """
  def validate(path) do
    {cmd, args} = if zip?(path), do: {"unzip", ["-Z", "-1", path]}, else: {"tar", ["-tf", path]}

    case @cmd_runner.cmd(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        if has_database_dump?(output),
          do: :ok,
          else:
            {:error,
             "That archive isn't a Wraft backup (no database.dump inside). Upload a Full backup archive."}

      {_output, _status} ->
        {:error, "That file isn't a valid .zip or .tar archive."}
    end
  end

  @doc """
  Extracts the archive into `staging`, refusing members that would escape it
  (zip-slip / tar-slip). Returns the runner's `{output, status}` (status 0 =
  ok) or `{:error, message}` when an archive is unsafe or unreadable.
  """
  def extract(path, staging) do
    if zip?(path) do
      # -j junks paths so a crafted archive can't escape staging via `../`
      # (zip-slip). We only consume three known flat members anyway.
      @cmd_runner.cmd("unzip", ["-o", "-j", "-qq", path, "-d", staging], stderr_to_stdout: true)
    else
      extract_tar(path, staging)
    end
  end

  # tar has no junk-paths flag, so refuse any archive whose members would
  # escape staging (absolute or `..`) before extracting — tar-slip parity.
  defp extract_tar(path, staging) do
    case @cmd_runner.cmd("tar", ["-tf", path], stderr_to_stdout: true) do
      {listing, 0} ->
        if safe_members?(listing),
          do: @cmd_runner.cmd("tar", ["-xf", path, "-C", staging], stderr_to_stdout: true),
          else: {:error, "import archive contains unsafe member paths"}

      {output, status} ->
        {:error, "could not read tar archive (exit #{status}): #{String.trim(output)}"}
    end
  end

  defp has_database_dump?(output) do
    output |> String.split("\n") |> Enum.any?(&String.ends_with?(&1, "database.dump"))
  end

  defp safe_members?(listing) do
    listing
    |> String.split("\n", trim: true)
    |> Enum.all?(fn member ->
      not String.starts_with?(member, "/") and ".." not in Path.split(member)
    end)
  end
end
