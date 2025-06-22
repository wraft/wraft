defmodule WraftDoc.Repo.Migrations.CreatePrompts do
  use Ecto.Migration

  def up do
    create table(:prompt, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:prompt, :text, null: false)
      add(:status, :string, null: false)
      add(:title, :string, null: false)
      add(:type, :string, null: false)

      add(:model_id, references(:ai_model, type: :uuid, column: :id, on_delete: :delete_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )

      timestamps(type: :utc_datetime)
    end

    create(index(:prompt, [:organisation_id]))
    create(index(:prompt, [:status]))

    create(unique_index(:prompt, [:title]))
  end

  def down do
    drop(index(:prompt, [:organisation_id]))
    drop(index(:prompt, [:status]))
    drop(unique_index(:prompt, [:title]))

    drop(table(:prompt))
  end
end
