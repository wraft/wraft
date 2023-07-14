defmodule WraftDoc.Repo.Migrations.AddInvitedUsersTable do
  use Ecto.Migration

  def change do
    create table(:invited_user, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:email, :string)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all)
      )

      add(:status, :string, default: "invited")

      timestamps()
    end

    create(unique_index(:invited_user, [:email, :organisation_id]))
  end
end
