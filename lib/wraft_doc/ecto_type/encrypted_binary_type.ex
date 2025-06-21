defmodule WraftDoc.EctoType.EncryptedBinaryType do
  @moduledoc """
  Ecto type for encrypted binary data.
  """

  use Cloak.Ecto.Binary, vault: WraftDoc.Utils.Vault
end
