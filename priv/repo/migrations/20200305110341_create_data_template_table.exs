defmodule WraftDoc.Repo.Migrations.CreateDataTemplateTable do
  use Ecto.Migration

  def up do
    create table(:data_template, primary_key: false) do
      add(:uuid, :uuid, null: false)
      add(:tag, :string, null: false)
      add(:data, :text, null: false)

      add(
        :content_type_id,
        references(:content_type, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end

  def down do
    drop_if_exists(table(:data_template))
  end
end
