defmodule WraftDoc.Repo.Migrations.UpdateCounterParties do
  @moduledoc """
  Migration to add signature-related fields to the counter_parties table.
  """
  use Ecto.Migration

  def up do
    alter table(:counter_parties) do
      add(:email, :string)
      add(:signature_status, :string, default: "pending")
      add(:signature_date, :utc_datetime)
      add(:signature_ip, :string)
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end

    create(unique_index(:counter_parties, [:user_id, :content_id]))
    create(index(:counter_parties, [:signature_status]))
    create(index(:counter_parties, [:email]))
  end

  def down do
    alter table(:counter_parties) do
      remove(:email)
      remove(:signature_status)
      remove(:signature_date)
      remove(:signature_ip)
      remove(:user_id)
    end

    drop_if_exists(unique_index(:counter_parties, [:user_id, :content_id]))
    drop_if_exists(index(:counter_parties, [:signature_status]))
    drop_if_exists(index(:counter_parties, [:email]))
  end
end
