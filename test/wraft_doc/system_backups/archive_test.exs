defmodule WraftDoc.SystemBackups.ArchiveTest do
  use ExUnit.Case, async: true

  import Mox

  alias WraftDoc.SystemBackups.Archive
  alias WraftDoc.SystemBackups.ZipStream

  setup :verify_on_exit!

  setup do
    stub(CmdRunnerMock, :cmd, fn cmd, args, opts when cmd in ["tar", "unzip"] ->
      System.cmd(cmd, args, opts)
    end)

    :ok
  end

  defp zip_with(names) do
    entries = Enum.map(names, &%{name: &1, size: byte_size(&1), stream: [&1]})
    bin = entries |> ZipStream.stream() |> Enum.to_list() |> IO.iodata_to_binary()
    path = Path.join(System.tmp_dir!(), "arc-#{System.unique_integer([:positive])}.zip")
    File.write!(path, bin)
    on_exit(fn -> File.rm_rf(path) end)
    path
  end

  test "zip?/1 detects a zip by its leading magic" do
    assert Archive.zip?(zip_with(["database.dump"]))
  end

  test "validate/1 accepts a zip that contains database.dump" do
    assert Archive.validate(zip_with(["database.dump", "bucket.tar", "manifest.json"])) == :ok
  end

  test "validate/1 rejects a zip with no database.dump member" do
    assert {:error, message} = Archive.validate(zip_with(["notes.txt"]))
    assert message =~ "database.dump"
  end

  test "extract/1 refuses a tar whose members escape staging (tar-slip)" do
    victim = Path.join(System.tmp_dir!(), "arc-slip-#{System.unique_integer([:positive])}.txt")
    File.write!(victim, "x")
    on_exit(fn -> File.rm_rf(victim) end)

    evil = Path.join(System.tmp_dir!(), "arc-evil-#{System.unique_integer([:positive])}.tar")
    {_, 0} = System.cmd("tar", ["-cPf", evil, victim])
    on_exit(fn -> File.rm_rf(evil) end)

    staging = Path.join(System.tmp_dir!(), "arc-stg-#{System.unique_integer([:positive])}")
    File.mkdir_p!(staging)
    on_exit(fn -> File.rm_rf(staging) end)

    assert {:error, message} = Archive.extract(evil, staging)
    assert message =~ "unsafe"
  end
end
