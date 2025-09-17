defmodule WraftDoc.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:url, :string, null: false)
      add(:secret, :string)
      add(:events, {:array, :string}, default: [])
      add(:is_active, :boolean, default: true)
      add(:headers, :map, default: %{})
      add(:retry_count, :integer, default: 3)
      add(:timeout_seconds, :integer, default: 30)
      add(:last_triggered_at, :utc_datetime)
      add(:last_response_status, :integer)
      add(:failure_count, :integer, default: 0)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )

      timestamps()
    end

    create(index(:webhooks, [:organisation_id]))
    create(index(:webhooks, [:is_active]))
    create(index(:webhooks, [:events], using: :gin))

    create(
      unique_index(:webhooks, [:name, :organisation_id],
        name: :webhooks_name_organisation_id_index
      )
    )
  end
end
