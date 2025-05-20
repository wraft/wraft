defmodule WraftDoc.Repo.Migrations.RemoveUniqueConstraintOnSignature do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:e_signature, [:content_id, :counter_party_id]))
  end
end
