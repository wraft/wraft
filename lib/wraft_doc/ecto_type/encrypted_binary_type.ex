defmodule WraftDoc.EctoType.EncryptedBinaryType do
  @moduledoc """
  Ecto type for storing encrypted binary data in the database.

  This module uses Cloak.Ecto.Binary to provide encryption/decryption
  functionality for binary data stored in the database.
  """

  use Cloak.Ecto.Binary, vault: WraftDoc.Utils.CloakVault
end
