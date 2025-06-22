defmodule WraftDoc.Utils.Vault do
  @moduledoc """
  Vault for encrypting and decrypting sensitive data.

  Environment variables:
    - CLOAK_KEY: (base64-encoded, recommended) Used for encryption. If not set, SECRET_KEY_BASE will be used to derive the key.
    - SECRET_KEY_BASE: (hex or base64) Used for key derivation if CLOAK_KEY is not set.

  Cipher: AES-GCM, 256-bit key.
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

        IO.warn(
          "CLOAK_KEY not set. Deriving encryption key from SECRET_KEY_BASE. " <>
            "It's recommended to set a dedicated CLOAK_KEY for stronger security."
        )

        derive_key_from_secret(secret_key_base)

      cloak_key_b64 ->
        cloak_key_b64
        |> Base.decode64()
        |> case do
          {:ok, key} -> key
          :error -> raise "CLOAK_KEY is not valid base64"
        end
    end
  end

  defp derive_key_from_secret(secret_key_base),
    do: :crypto.pbkdf2_hmac(:sha256, secret_key_base, "cloak_salt", 4096, 32)
end
