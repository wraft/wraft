defmodule WraftDoc.Storage.PublicEndpoint do
  @moduledoc """
  ExAws config for URLs opened by a browser.

  API calls keep `S3_HOST`, which is the in-network address. Presigned URLs
  use `S3_URL`, which is the address the browser can reach.
  """

  def config do
    base = ExAws.Config.new(:s3, Application.get_all_env(:ex_aws))

    case endpoint() do
      nil -> base
      public -> Map.merge(base, public)
    end
  end

  defp endpoint do
    case System.get_env("S3_URL") do
      url when is_binary(url) and url != "" ->
        url = if String.contains?(url, "://"), do: url, else: "http://#{url}"
        parse(url)

      _ ->
        nil
    end
  end

  defp parse(url) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(url)

    if is_binary(host) and host != "" do
      scheme = scheme || "http"

      %{
        scheme: scheme <> "://",
        host: host,
        port: port || if(scheme == "https", do: 443, else: 80)
      }
    end
  end
end
