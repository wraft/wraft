defmodule Mix.Tasks.Wraft.CheckDeps do
  @moduledoc """
  Checks if PostgreSQL database and MinIO bucket are available before proceeding with setup.

  ## Examples

      $ mix wraft.check_deps
  """

  @shortdoc "Checks database and bucket availability"

  use Mix.Task
  require Logger

  @requirements ["app.config"]

  def run(_) do
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:hackney)
    Application.ensure_all_started(:ex_aws)
    Application.ensure_all_started(:ex_aws_s3)

    with :ok <- check_database_connection(),
         :ok <- check_minio_connection() do
      IO.puts("\n✅ All dependencies are available and properly configured!\n")
    end
  end

  defp get_database_url do
    repo_config = Application.get_env(:wraft_doc, WraftDoc.Repo)

    Keyword.get(repo_config, :url) || System.get_env("DATABASE_URL")
  end

  defp parse_database_url(database_url) do
    %URI{
      userinfo: userinfo,
      host: hostname,
      port: port,
      path: _path
    } = URI.parse(database_url)

    {username, password} =
      case String.split(userinfo || "", ":") do
        [username, password] -> {username, password}
        _ -> {"postgres", "postgres"}
      end

    port = if is_binary(port), do: String.to_integer(port), else: port || 5432

    {hostname, port, username, password}
  end

  defp check_database_connection do
    IO.puts("\nChecking PostgreSQL connection...")

    database_url = get_database_url()
    {hostname, port, username, password} = parse_database_url(database_url)

    case Postgrex.start_link(
           hostname: hostname,
           port: port,
           username: username,
           password: password,
           database: "postgres"
         ) do
      {:ok, pid} ->
        GenServer.stop(pid)
        IO.puts("✅ PostgreSQL is running and accepting connections")
        :ok

      {:error, %{postgres: %{message: message}}} ->
        IO.puts("\n❌ PostgreSQL Error: #{message}")
        IO.puts("\nTroubleshooting steps:")
        IO.puts("1. Check if PostgreSQL is running:")
        IO.puts("   - Mac: brew services list")
        IO.puts("   - Linux: sudo systemctl status postgresql")
        IO.puts("2. Verify your database credentials in config/dev.exs")
        IO.puts("3. Make sure your DATABASE_URL is set correctly:")
        IO.puts("   Current connection info:")
        IO.puts("   - Host: #{hostname}")
        IO.puts("   - Port: #{port}")
        IO.puts("   - Username: #{username}")
        raise "PostgreSQL connection failed"

      {:error, error} ->
        IO.puts("\n❌ PostgreSQL Error: #{inspect(error)}")
        IO.puts("\nTroubleshooting steps:")
        IO.puts("1. Check if PostgreSQL is running")
        IO.puts("2. Verify your database configuration")
        IO.puts("3. Current connection settings:")
        IO.puts("   Host: #{hostname}")
        IO.puts("   Port: #{port}")
        IO.puts("   Username: #{username}")
        raise "PostgreSQL connection failed"
    end
  end

  defp check_minio_connection do
    IO.puts("\nChecking RustFS connection...")
    endpoint = s3_endpoint()

    config =
      ExAws.Config.new(:s3,
        http_client: ExAws.Request.Hackney,
        retries: [max_attempts: 1],
        http_opts: [timeout: 5_000, recv_timeout: 5_000]
      )

    request = ExAws.S3.list_buckets()

    case ExAws.request(request, config) do
      {:ok, _} ->
        IO.puts("✅ RustFS is running and accessible")
        :ok

      {:error, :econnrefused} ->
        IO.puts("\n❌ RustFS Error: Connection refused")
        IO.puts("\nTroubleshooting steps:")
        IO.puts("1. Check if RustFS is running:")
        IO.puts("   - If using Docker: docker ps | grep rustfs")
        IO.puts("   - Check S3 endpoint: #{endpoint}")
        IO.puts("2. Verify S3_HOST, S3_PORT, and S3_URL:")
        IO.puts("   Current endpoint: #{endpoint}")
        IO.puts("3. If using Docker, make sure the container is running:")
        IO.puts("   - docker-compose up -d")
        raise "RustFS connection failed"

      {:error, error} ->
        IO.puts("\n❌ RustFS Error: #{inspect(error)}")
        IO.puts("\nTroubleshooting steps:")
        IO.puts("1. Verify S3 configuration:")
        IO.puts("   - S3 endpoint: #{endpoint}")
        IO.puts("2. Check RustFS logs for errors")
        IO.puts("3. Ensure RustFS service is running")
        raise "RustFS connection failed"
    end
  end

  defp s3_endpoint do
    case System.get_env("S3_URL") do
      url when is_binary(url) and url != "" ->
        if String.contains?(url, "://"), do: url, else: "http://#{url}"

      _ ->
        host = System.get_env("S3_HOST") || "localhost"
        port = System.get_env("S3_PORT") || "9000"
        scheme = System.get_env("S3_SCHEMA") || "http"
        "#{scheme}://#{host}:#{port}"
    end
  end
end
