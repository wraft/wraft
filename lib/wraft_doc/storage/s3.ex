defmodule WraftDoc.Storage.S3 do
  @moduledoc """
  Waffle storage that signs browser URLs with `S3_URL`.
  """

  @default_expiry_time 60 * 5

  defdelegate put(definition, version, file_and_scope), to: Waffle.Storage.S3
  defdelegate delete(definition, version, file_and_scope), to: Waffle.Storage.S3

  def url(definition, version, file_and_scope, options \\ []) do
    if Keyword.get(options, :signed, false) do
      signed_url(definition, version, file_and_scope, options)
    else
      Waffle.Storage.S3.url(definition, version, file_and_scope, options)
    end
  end

  defp signed_url(definition, version, file_and_scope, options) do
    options = Keyword.drop(options, [:signed])
    expires_in = options[:expires_in] || options[:expire_in] || @default_expiry_time
    options = Keyword.merge(options, expires_in: expires_in, virtual_host: virtual_host())

    {:ok, url} =
      ExAws.S3.presigned_url(
        WraftDoc.Storage.PublicEndpoint.config(),
        :get,
        bucket(definition, file_and_scope),
        Waffle.Storage.S3.s3_key(definition, version, file_and_scope),
        options
      )

    url
  end

  defp bucket(definition, file_and_scope) do
    case definition.bucket(file_and_scope) do
      {:system, env} when is_binary(env) -> System.get_env(env)
      name -> name
    end
  end

  defp virtual_host, do: Application.get_env(:waffle, :virtual_host) || false
end
