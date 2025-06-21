defmodule WraftDoc.Utils.Vault do
  @moduledoc """
    Vault for encrypting and decrypting sensitive data.
  """
  use Cloak.Vault, otp_app: :wraft_doc
end
