defmodule WraftDoc.Repo.Migrations.CreateWebhookLogs do
  use Ecto.Migration

  def change do
    create table(:webhook_logs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:event, :string, null: false)
      add(:url, :string, null: false)
      add(:http_method, :string, default: "POST")
      add(:request_headers, :map, default: %{})
      add(:request_body, :text)
      add(:response_status, :integer)
      add(:response_headers, :map, default: %{})
      add(:response_body, :text)
      add(:execution_time_ms, :integer)
      add(:success, :boolean, default: false)
      add(:error_message, :text)
      add(:attempt_number, :integer, default: 1)
      add(:triggered_at, :utc_datetime, null: false)

      add(:webhook_id, references(:webhooks, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(index(:webhook_logs, [:webhook_id]))
    create(index(:webhook_logs, [:organisation_id]))
    create(index(:webhook_logs, [:triggered_at]))
    create(index(:webhook_logs, [:success]))
    create(index(:webhook_logs, [:event]))
    create(index(:webhook_logs, [:webhook_id, :triggered_at]))
  end
end
