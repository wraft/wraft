defmodule WraftDoc.SystemBackups.RemoteTargetTest do
  use ExUnit.Case, async: true

  alias WraftDoc.SystemBackups.RemoteTarget

  describe "private_ip?/1 (SSRF classifier)" do
    test "flags private/loopback/link-local IPv4" do
      for ip <- [
            {127, 0, 0, 1},
            {10, 1, 2, 3},
            {172, 16, 0, 1},
            {192, 168, 1, 1},
            {169, 254, 0, 1},
            {0, 0, 0, 0}
          ] do
        assert RemoteTarget.private_ip?(ip), "expected #{inspect(ip)} to be private"
      end
    end

    test "allows public IPv4" do
      for ip <- [{8, 8, 8, 8}, {1, 1, 1, 1}, {93, 184, 216, 34}] do
        refute RemoteTarget.private_ip?(ip), "expected #{inspect(ip)} to be public"
      end
    end

    test "flags private/loopback/link-local/ULA IPv6" do
      for ip <- [
            # ::1 loopback
            {0, 0, 0, 0, 0, 0, 0, 1},
            # :: unspecified
            {0, 0, 0, 0, 0, 0, 0, 0},
            # fe80::1 link-local
            {0xFE80, 0, 0, 0, 0, 0, 0, 1},
            # fc00::/7 unique-local
            {0xFD12, 0x3456, 0, 0, 0, 0, 0, 1},
            # ::ffff:127.0.0.1 IPv4-mapped loopback
            {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001}
          ] do
        assert RemoteTarget.private_ip?(ip), "expected #{inspect(ip)} to be private"
      end
    end

    test "allows public IPv6 (incl. IPv4-mapped public)" do
      for ip <- [
            # 2606:2800:220:1::/public
            {0x2606, 0x2800, 0x0220, 1, 0, 0, 0, 0},
            # ::ffff:8.8.8.8 IPv4-mapped public
            {0, 0, 0, 0, 0, 0xFFFF, 0x0808, 0x0808}
          ] do
        refute RemoteTarget.private_ip?(ip), "expected #{inspect(ip)} to be public"
      end
    end
  end

  describe "validate/1" do
    test "refuses localhost (resolves to a loopback address)" do
      remote = %{
        remote_database_url: "postgres://u:p@localhost:5432/restore_target",
        remote_s3_endpoint: "http://localhost:9000",
        remote_s3_bucket: "restore-bucket"
      }

      assert {:error, reason} = RemoteTarget.validate(remote)
      assert reason =~ "private/loopback"
    end

    test "pin_host/1 refuses localhost (resolves private) so pg_restore can't be pinned to it" do
      assert {:error, reason} = RemoteTarget.pin_host("localhost")
      assert reason =~ "private/loopback"
    end

    test "refuses a remote DB URL with no database name" do
      remote = %{
        remote_database_url: "postgres://u:p@example.com:5432/",
        remote_s3_endpoint: "https://s3.example.com",
        remote_s3_bucket: "restore-bucket"
      }

      assert {:error, reason} = RemoteTarget.validate(remote)
      assert reason =~ "must include a database name"
    end
  end
end
