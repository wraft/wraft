defmodule WraftDoc.Sentry.Scrubber do
  @moduledoc """
  `before_send` callback that redacts secret material (database URL /
  password, cloak key, secret key base) from Sentry events, so an
  unhandled exception raised around a credentialed shell-out (e.g. the
  backup engine's pg_dump) can never ship a connection string to Sentry.
  """

  @secret_env_keys ~w(DATABASE_URL PGPASSWORD CLOAK_KEY SECRET_KEY_BASE SESSION_SIGNING_SALT)

  def scrub(event) do
    case secrets() do
      [] -> event
      secrets -> scrub_term(event, secrets)
    end
  end

  defp secrets do
    direct = Enum.map(@secret_env_keys, &System.get_env/1)

    db_passwords = WraftDoc.DatabaseUrl.password_secrets(System.get_env("DATABASE_URL"))

    (direct ++ db_passwords)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp scrub_term(value, secrets) when is_binary(value) do
    Enum.reduce(secrets, value, &String.replace(&2, &1, "[REDACTED]"))
  end

  defp scrub_term(%_struct{} = value, secrets) do
    value
    |> Map.from_struct()
    |> Enum.reduce(value, fn {key, field}, acc ->
      Map.put(acc, key, scrub_term(field, secrets))
    end)
  end

  defp scrub_term(value, secrets) when is_map(value) do
    Map.new(value, fn {key, field} -> {key, scrub_term(field, secrets)} end)
  end

  defp scrub_term(value, secrets) when is_list(value) do
    Enum.map(value, &scrub_term(&1, secrets))
  end

  defp scrub_term(value, _secrets), do: value
end
