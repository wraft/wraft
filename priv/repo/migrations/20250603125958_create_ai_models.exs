defmodule WraftDoc.Repo.Migrations.CreateAiModels do
  use Ecto.Migration

  def up do
    create table(:ai_model, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:description, :text)
      add(:status, :string)
      add(:auth_key, :binary)
      add(:provider, :string)
      add(:daily_request_limit, :integer)
      add(:daily_token_limit, :integer)
      add(:endpoint_url, :string)
      add(:is_local, :boolean, default: false)
      add(:is_thinking_model, :boolean, default: false)
      add(:model_name, :string)
      add(:model_type, :string)
      add(:model_version, :string)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:ai_model, [:organisation_id]))
    create(index(:ai_model, [:provider]))
    create(index(:ai_model, [:status]))

    create(unique_index(:ai_model, [:name]))
    create(unique_index(:ai_model, [:model_name]))
  end

  def down do
    drop(index(:ai_model, [:organisation_id]))
    drop(index(:ai_model, [:provider]))
    drop(index(:ai_model, [:status]))
    drop(index(:ai_model, [:name]))
    drop(index(:ai_model, [:model_name]))

    drop(table(:ai_model))
  end
end
