defmodule WraftDoc.Utils.Vault do
  @moduledoc """
    Vault for encrypting and decrypting sensitive data.
  """
  use Cloak.Vault, otp_app: :wraft_doc

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: get_encryption_key()}
      )

    {:ok, config}
  end

  defp get_encryption_key do
    "CLOAK_KEY"
    |> System.get_env()
    |> case do
      nil ->
        secret_key_base =
          System.get_env("SECRET_KEY_BASE") ||
            raise "Either CLOAK_KEY or SECRET_KEY_BASE must be set"

        derive_key_from_secret(secret_key_base)

      cloak_key ->
        Base.decode64!(cloak_key)
    end
  end

  defp derive_key_from_secret(secret_key_base),
    do: :crypto.pbkdf2_hmac(:sha256, secret_key_base, "cloak_salt", 4096, 32)
end
