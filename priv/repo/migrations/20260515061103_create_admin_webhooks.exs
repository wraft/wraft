defmodule WraftDoc.Repo.Migrations.CreateAdminWebhooks do
  use Ecto.Migration

  def change do
    create table(:admin_webhooks, primary_key: false) do
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
        :creator_id,
        references(:internal_user, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:admin_webhooks, [:is_active]))
    create(index(:admin_webhooks, [:events], using: :gin))
    create(unique_index(:admin_webhooks, [:name], name: :admin_webhooks_name_index))
  end
end
