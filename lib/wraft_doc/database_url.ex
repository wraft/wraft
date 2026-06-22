defmodule WraftDoc.DatabaseUrl do
  @moduledoc """
  Parsing helpers for `DATABASE_URL`-style connection strings, shared by
  the backup engine (to build a credential-free `pg_dump` env and to
  scrub error output) and the Sentry scrubber (to redact secrets from
  events). Centralized so the two never diverge on, e.g., percent-encoded
  passwords.
  """

  @doc """
  Returns the userinfo credentials as `{user, raw_password,
  decoded_password}`. Any element is `nil` when absent. Both the raw and
  URI-decoded password forms are returned so callers that scrub output
  catch a password regardless of how it appears in a given string.
  """
  @spec credentials(String.t() | nil) :: {String.t() | nil, String.t() | nil, String.t() | nil}
  def credentials(nil), do: {nil, nil, nil}

  def credentials(url) when is_binary(url) do
    case URI.parse(url).userinfo do
      nil ->
        {nil, nil, nil}

      userinfo ->
        case String.split(userinfo, ":", parts: 2) do
          [user, password] -> {URI.decode(user), password, URI.decode(password)}
          [user] -> {URI.decode(user), nil, nil}
        end
    end
  end

  @doc "The password forms (raw + decoded) worth redacting, with nils/dupes removed."
  @spec password_secrets(String.t() | nil) :: [String.t()]
  def password_secrets(url) do
    {_user, raw, decoded} = credentials(url)

    [raw, decoded]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end
end
