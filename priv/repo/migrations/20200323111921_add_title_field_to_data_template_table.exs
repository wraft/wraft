defmodule WraftDoc.Repo.Migrations.AddTitleFieldToDataTemplateTable do
  use Ecto.Migration

  def up do
    alter table(:data_template) do
      add(:title_template, :string)
    end

    rename(table(:data_template), :tag, to: :title)
  end

  def down do
    rename(table(:data_template), :title, to: :tag)

    alter table(:data_template) do
      remove(:title_template)
    end
  end
end
