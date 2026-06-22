defmodule WraftDoc.SystemBackups.ZipStreamTest do
  use ExUnit.Case, async: true

  alias WraftDoc.SystemBackups.ZipStream

  defp build(entries),
    do: entries |> ZipStream.stream() |> Enum.to_list() |> IO.iodata_to_binary()

  defp write_tmp(bin) do
    path = Path.join(System.tmp_dir!(), "zs-#{System.unique_integer([:positive])}.zip")
    File.write!(path, bin)
    on_exit(fn -> File.rm_rf(path) end)
    path
  end

  defp extract(entries) do
    out = Path.join(System.tmp_dir!(), "zs-out-#{System.unique_integer([:positive])}")
    File.mkdir_p!(out)
    on_exit(fn -> File.rm_rf(out) end)
    {_, 0} = System.cmd("unzip", ["-o", "-qq", write_tmp(build(entries)), "-d", out])
    out
  end

  test "builds a zip that passes unzip's CRC integrity check" do
    bin = build([%{name: "a.txt", size: 12, stream: ["aaaa", "bbbb", "cccc"]}])
    assert {_out, 0} = System.cmd("unzip", ["-t", write_tmp(bin)])
  end

  test "extracts each member with its exact bytes (CRC folded across chunks)" do
    out =
      extract([
        %{name: "database.dump", size: 12, stream: ["aaaa", "bbbb", "cccc"]},
        %{name: "manifest.json", size: 5, stream: ["hello"]}
      ])

    assert File.read!(Path.join(out, "database.dump")) == "aaaabbbbcccc"
    assert File.read!(Path.join(out, "manifest.json")) == "hello"
  end

  test "preserves arbitrary binary content" do
    out = extract([%{name: "blob.bin", size: 6, stream: [<<0, 1, 2>>, <<253, 254, 255>>]}])
    assert File.read!(Path.join(out, "blob.bin")) == <<0, 1, 2, 253, 254, 255>>
  end

  test "handles an empty entry" do
    out = extract([%{name: "empty", size: 0, stream: []}])
    assert File.read!(Path.join(out, "empty")) == ""
  end
end
