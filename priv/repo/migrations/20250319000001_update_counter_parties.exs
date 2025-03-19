defmodule WraftDoc.Repo.Migrations.UpdateCounterParties do
  @moduledoc """
  Migration to add signature-related fields to the counter_parties table.
  """
  use Ecto.Migration

  def change do
    alter table(:counter_parties, primary_key: false) do
      # Add fields only if they don't already exist
      add_if_not_exists(:email, :string)
      add_if_not_exists(:signature_status, :string, default: "pending")
      add_if_not_exists(:signature_date, :utc_datetime)
      add_if_not_exists(:signature_ip, :string)
    end

    # Add indices if they don't already exist
    create_if_not_exists(index(:counter_parties, [:guest_user_id]))
    create_if_not_exists(index(:counter_parties, [:signature_status]))
    create_if_not_exists(index(:counter_parties, [:content_id]))
    create_if_not_exists(index(:counter_parties, [:email]))
  end
end
