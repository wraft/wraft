defmodule WraftDoc.Repo.Migrations.UpdateRawFieldToTextTypeInVersionTable do
  use Ecto.Migration

  def change do
    alter table(:version) do
      modify(:raw, :text, from: :string)
    end
  end
end
