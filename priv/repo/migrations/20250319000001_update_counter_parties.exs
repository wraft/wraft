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

      timestamps()
    end

    create(index(:counter_parties, [:guest_user_id]))
    create(index(:counter_parties, [:signature_status]))
    create(index(:counter_parties, [:content_id]))
    create(index(:counter_parties, [:email]))
  end

  def down do
    alter table(:counter_parties) do
      remove(:email)
      remove(:signature_status)
      remove(:signature_date)
      remove(:signature_ip)
    end

    drop_if_exists(index(:counter_parties, [:guest_user_id]))
    drop_if_exists(index(:counter_parties, [:signature_status]))
    drop_if_exists(index(:counter_parties, [:content_id]))
    drop_if_exists(index(:counter_parties, [:email]))
  end
end
