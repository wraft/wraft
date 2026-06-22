defmodule WraftDoc.SystemBackups.RemoteTarget do
  @moduledoc """
  Guards the operator-supplied target of a REMOTE restore ("another site").

  Remote restore makes outbound `pg_restore` + S3 connections to a host the
  operator types in, against an unencrypted all-tenant backup. So it is:

    * **off by default** — enabled only when `remote_restore_enabled` is set;
    * **SSRF-guarded** — the remote DB and S3 hosts must not resolve to a
      private / loopback / link-local range, IPv4 **or** IPv6 (override with
      an explicit `remote_allowed_hosts` allowlist);
    * **live-target-guarded** — refuses a remote whose database matches the
      live `DATABASE_URL` or whose bucket matches the live `MINIO_BUCKET`
      (`pg_restore --clean` would destroy the live instance).

  Resolution happens at validate time. `pg_restore`/S3 re-resolve the hostname
  when they connect, so a host that flips DNS between validate and connect
  (DNS rebinding) is not fully closed by resolution alone — the allowlist is
  the primary control for untrusted networks; pinning the resolved IP across
  both the pg and S3 connections is a known follow-up.
  """
  import Bitwise

  # {network, prefix-bits} for IPv4 ranges we refuse to connect to.
  @private_v4 [
    {{0, 0, 0, 0}, 8},
    {{10, 0, 0, 0}, 8},
    {{127, 0, 0, 0}, 8},
    {{169, 254, 0, 0}, 16},
    {{172, 16, 0, 0}, 12},
    {{192, 168, 0, 0}, 16}
  ]

  @doc "Whether remote restore is enabled at all (default OFF)."
  def enabled? do
    Application.get_env(:wraft_doc, :system_backup, [])[:remote_restore_enabled] == true
  end

  @doc "Validates a remote target. Returns `:ok` or `{:error, reason}`."
  def validate(%{
        remote_database_url: db_url,
        remote_s3_endpoint: endpoint,
        remote_s3_bucket: bucket
      })
      when is_binary(db_url) and is_binary(endpoint) and is_binary(bucket) do
    with :ok <- require_database(db_url),
         :ok <- check_host(host_of(db_url)),
         :ok <- check_host(host_of(endpoint)) do
      refuse_live_target(db_url, bucket)
    end
  end

  def validate(_), do: {:error, "incomplete remote target"}

  defp require_database(url) do
    case URI.parse(url).path do
      "/" <> rest when rest != "" -> :ok
      _ -> {:error, "remote Postgres URL must include a database name"}
    end
  end

  defp host_of(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> url
    end
  end

  @doc """
  Resolves `host` for an outbound remote-restore connection and returns the IP
  to pin (`PGHOSTADDR`) so the later `pg_restore` doesn't re-resolve the name
  and rebind to an internal address. Returns `{:ok, ip | nil}` — `nil` when the
  host was trusted via the allowlist or the `:any` bypass (no pin) — or
  `{:error, reason}` when it doesn't resolve or resolves to a private range.
  """
  def pin_host(host) do
    case allowlist() do
      # Escape hatch (config/tests can set `remote_allowed_hosts: :any`) to skip
      # DNS-based checks/pinning; the live-target guard still applies.
      :any ->
        {:ok, nil}

      [] ->
        resolve_pinned(host)

      list when is_list(list) ->
        if host in list,
          do: {:ok, nil},
          else: {:error, "remote host #{host} is not in the allowlist"}
    end
  end

  defp check_host(host) do
    case pin_host(host) do
      {:ok, _ip} -> :ok
      {:error, _} = error -> error
    end
  end

  defp allowlist do
    Application.get_env(:wraft_doc, :system_backup, [])[:remote_allowed_hosts] || []
  end

  defp resolve_pinned(host) do
    charlist = String.to_charlist(host)
    addrs = resolve(charlist, :inet) ++ resolve(charlist, :inet6)

    cond do
      addrs == [] ->
        {:error, "remote host #{host} did not resolve"}

      Enum.any?(addrs, &private_ip?/1) ->
        {:error, "remote host #{host} resolves to a private/loopback address — refusing"}

      true ->
        # Pin the first resolved address (v4 preferred) for the connection.
        {:ok, addrs |> hd() |> :inet.ntoa() |> to_string()}
    end
  end

  defp resolve(charlist, family) do
    case :inet.getaddrs(charlist, family) do
      {:ok, addrs} -> addrs
      {:error, _} -> []
    end
  end

  @doc false
  # Whether a resolved address (IPv4 4-tuple or IPv6 8-tuple) is in a range we
  # refuse to connect to. Public for testing the SSRF classifier directly.
  def private_ip?({_, _, _, _} = v4), do: private_v4?(v4)
  def private_ip?({_, _, _, _, _, _, _, _} = v6), do: private_v6?(v6)

  defp private_v4?(addr) do
    Enum.any?(@private_v4, fn {net, bits} -> in_cidr?(addr, net, bits) end)
  end

  # ::/128 unspecified, ::1 loopback, ::ffff:a.b.c.d IPv4-mapped (delegate to
  # the v4 ranges), fe80::/10 link-local, fc00::/7 unique-local.
  defp private_v6?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp private_v6?({0, 0, 0, 0, 0, 0, 0, 1}), do: true

  defp private_v6?({0, 0, 0, 0, 0, 0xFFFF, g, h}),
    do: private_v4?({g >>> 8, g &&& 0xFF, h >>> 8, h &&& 0xFF})

  defp private_v6?({first, _, _, _, _, _, _, _}),
    do: (first &&& 0xFFC0) == 0xFE80 or (first &&& 0xFE00) == 0xFC00

  defp in_cidr?({a, b, c, d}, {na, nb, nc, nd}, bits) do
    ip = a <<< 24 ||| b <<< 16 ||| c <<< 8 ||| d
    net = na <<< 24 ||| nb <<< 16 ||| nc <<< 8 ||| nd
    mask = if bits == 0, do: 0, else: bnot((1 <<< (32 - bits)) - 1) &&& 0xFFFFFFFF
    (ip &&& mask) == (net &&& mask)
  end

  defp refuse_live_target(db_url, bucket) do
    cond do
      same_database?(db_url, System.get_env("DATABASE_URL")) ->
        {:error, "refusing to restore onto the live database"}

      bucket == System.get_env("MINIO_BUCKET") ->
        {:error, "refusing to restore into the live bucket"}

      true ->
        :ok
    end
  end

  defp same_database?(_remote, nil), do: false

  defp same_database?(remote, live) do
    r = URI.parse(remote)
    l = URI.parse(live)
    r.host == l.host and r.port == l.port and r.path == l.path
  end
end
