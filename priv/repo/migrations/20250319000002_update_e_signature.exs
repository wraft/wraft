defmodule WraftDoc.Repo.Migrations.UpdateESignature do
  @moduledoc """
  Migration to add signature-related fields to the e_signature table.
  """
  use Ecto.Migration

  def change do
    alter table(:e_signature) do
      add(:signature_type, :string, default: "digital")
      add(:signature_data, :map)
      add(:signature_position, :map)
      add(:signature_date, :utc_datetime)
      add(:is_valid, :boolean, default: false)
      add(:verification_token, :string)
      add(:counter_party_id, references(:counter_parties, type: :binary_id, on_delete: :nothing))
    end

    create(index(:e_signature, [:counter_party_id]))
    create(index(:e_signature, [:signature_date]))
    create(index(:e_signature, [:is_valid]))
  end
end
