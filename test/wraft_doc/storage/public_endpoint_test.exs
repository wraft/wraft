defmodule WraftDoc.Storage.PublicEndpointTest do
  use ExUnit.Case, async: false

  alias WraftDoc.Storage.PublicEndpoint

  setup do
    previous = System.get_env("S3_URL")

    on_exit(fn ->
      if previous, do: System.put_env("S3_URL", previous), else: System.delete_env("S3_URL")
    end)

    :ok
  end

  test "presigned config uses the host and port from S3_URL" do
    System.put_env("S3_URL", "http://127.0.0.1:19000")

    config = PublicEndpoint.config()

    assert config.scheme == "http://"
    assert config.host == "127.0.0.1"
    assert config.port == 19_000
  end

  test "S3_URL without a scheme still sets the public port" do
    System.put_env("S3_URL", "127.0.0.1:9000")

    config = PublicEndpoint.config()

    assert config.scheme == "http://"
    assert config.host == "127.0.0.1"
    assert config.port == 9000
  end
end
