defmodule WraftDoc.SystemBackups.ZipStream do
  @moduledoc """
  Builds a ZIP (STORE method, ZIP64, streaming data descriptors) as a lazy
  stream of binary chunks, so the combined "full" backup download is
  assembled on the fly from the separately-stored parts without ever holding
  a part in memory or on disk.

  STORE (no compression): the parts are a `pg_dump` and an already-tarred
  bucket mirror — deflate would burn CPU for ~0 ratio (same rationale as the
  tar builder). CRC-32 is unknown until the bytes flow, so it is computed
  while streaming each entry and written in a trailing data descriptor;
  ZIP64 fields are always emitted so parts larger than 4 GB work.

  Each entry is `%{name: String.t(), size: non_neg_integer(), stream:
  Enumerable.t()}` where `stream` yields the entry's bytes. Output extracts
  with `unzip` / libarchive and any ZIP64-aware tool.
  """

  @sig_local 0x04034B50
  @sig_descriptor 0x08074B50
  @sig_central 0x02014B50
  @sig_zip64_eocd 0x06064B50
  @sig_zip64_locator 0x07064B50
  @sig_eocd 0x06054B50

  @version 45
  @flag_descriptor 0x0008
  @dos_date 0x21
  @z64 0xFFFFFFFF

  @spec stream([map()]) :: Enumerable.t()
  def stream(entries) do
    events =
      entries
      |> Stream.flat_map(fn %{name: name, stream: body} ->
        Stream.concat([[{:header, name}], Stream.map(body, &{:data, &1}), [:descriptor]])
      end)
      |> Stream.concat([:finalize])

    Stream.transform(events, init(), &reduce/2)
  end

  defp init, do: %{offset: 0, dir: [], cur: nil, crc: 0, written: 0}

  defp reduce({:header, name}, acc) do
    bin = local_header(name)
    cur = %{name: name, offset: acc.offset}
    {[bin], %{acc | cur: cur, crc: 0, written: 0, offset: acc.offset + byte_size(bin)}}
  end

  defp reduce({:data, chunk}, acc) do
    {[chunk],
     %{
       acc
       | crc: :erlang.crc32(acc.crc, chunk),
         written: acc.written + byte_size(chunk),
         offset: acc.offset + byte_size(chunk)
     }}
  end

  defp reduce(:descriptor, acc) do
    bin = data_descriptor(acc.crc, acc.written)
    entry = Map.merge(acc.cur, %{crc: acc.crc, size: acc.written})
    {[bin], %{acc | dir: [entry | acc.dir], cur: nil, offset: acc.offset + byte_size(bin)}}
  end

  defp reduce(:finalize, acc) do
    entries = Enum.reverse(acc.dir)
    central = Enum.map(entries, &central_header/1)
    cd_offset = acc.offset
    cd_size = central |> Enum.map(&byte_size/1) |> Enum.sum()

    trailer =
      zip64_eocd(length(entries), cd_size, cd_offset) <>
        zip64_locator(cd_offset + cd_size) <>
        eocd(length(entries))

    {central ++ [trailer], acc}
  end

  defp local_header(name) do
    extra = <<0x0001::little-16, 16::little-16, 0::little-64, 0::little-64>>

    <<@sig_local::little-32, @version::little-16, @flag_descriptor::little-16, 0::little-16,
      0::little-16, @dos_date::little-16, 0::little-32, @z64::little-32, @z64::little-32,
      byte_size(name)::little-16, byte_size(extra)::little-16, name::binary, extra::binary>>
  end

  defp data_descriptor(crc, size) do
    <<@sig_descriptor::little-32, crc::little-32, size::little-64, size::little-64>>
  end

  defp central_header(%{name: name, crc: crc, size: size, offset: offset}) do
    extra =
      <<0x0001::little-16, 24::little-16, size::little-64, size::little-64, offset::little-64>>

    <<@sig_central::little-32, @version::little-16, @version::little-16,
      @flag_descriptor::little-16, 0::little-16, 0::little-16, @dos_date::little-16,
      crc::little-32, @z64::little-32, @z64::little-32, byte_size(name)::little-16,
      byte_size(extra)::little-16, 0::little-16, 0::little-16, 0::little-16, 0::little-32,
      @z64::little-32, name::binary, extra::binary>>
  end

  defp zip64_eocd(count, cd_size, cd_offset) do
    <<@sig_zip64_eocd::little-32, 44::little-64, @version::little-16, @version::little-16,
      0::little-32, 0::little-32, count::little-64, count::little-64, cd_size::little-64,
      cd_offset::little-64>>
  end

  defp zip64_locator(offset) do
    <<@sig_zip64_locator::little-32, 0::little-32, offset::little-64, 1::little-32>>
  end

  defp eocd(count) do
    c = min(count, 0xFFFF)

    <<@sig_eocd::little-32, 0::little-16, 0::little-16, c::little-16, c::little-16,
      @z64::little-32, @z64::little-32, 0::little-16>>
  end
end
