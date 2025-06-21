defmodule WraftDoc.Repo.Migrations.CreateModelGenerateLog do
  use Ecto.Migration

  def up do
    create table(:ai_model_log, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:prompt_text, :text, null: false)
      add(:model_name, :string, null: false)
      add(:provider, :string)
      add(:endpoint, :string)
      add(:status, :string, null: false)
      add(:response, :text)
      add(:response_time_ms, :integer, null: false)

      add(:model_id, references(:ai_model, type: :uuid, on_delete: :nothing))

      add(:prompt_id, references(:prompt, type: :uuid, on_delete: :nothing))

      add(:user_id, references(:user, type: :uuid, on_delete: :nothing))

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nothing))

      timestamps()
    end
  end

  def down do
    drop(table(:ai_model_log))
  end
end
