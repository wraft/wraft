defmodule WraftDoc.Repo.Migrations.UpdateESignature do
  @moduledoc """
  Migration to add signature-related fields to the e_signature table.
  """
  use Ecto.Migration

  def up do
    alter table(:e_signature) do
      add(:signature_type, :string, default: "digital")
      add(:signature_data, :map)
      add(:signature_position, :map)
      add(:ip_address, :string)
      add(:signature_date, :utc_datetime)
      add(:is_valid, :boolean, default: false)
      add(:verification_token, :string)
      add(:counter_party_id, references(:counter_parties, type: :binary_id, on_delete: :nothing))
    end

    create(unique_index(:e_signature, [:verification_token]))
    create(index(:e_signature, [:counter_party_id]))
    create(index(:e_signature, [:signature_date]))
    create(index(:e_signature, [:is_valid]))
  end

  def down do
    drop_if_exists(unique_index(:e_signature, [:verification_token]))
    drop_if_exists(index(:e_signature, [:is_valid]))
    drop_if_exists(index(:e_signature, [:signature_date]))
    drop_if_exists(index(:e_signature, [:counter_party_id]))

    alter table(:e_signature) do
      remove(:counter_party_id)
      remove(:verification_token)
      remove(:is_valid)
      remove(:signature_date)
      remove(:signature_position)
      remove(:signature_data)
      remove(:signature_type)
      remove(:ip_address, :string)
    end
  end
end
