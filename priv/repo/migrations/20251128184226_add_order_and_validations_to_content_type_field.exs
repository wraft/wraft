defmodule WraftDoc.Repo.Migrations.AddOrderAndValidationsToContentTypeField do
  use Ecto.Migration

  def up do
    alter table(:content_type_field) do
      add(:order, :integer, default: 0)
      add(:validations, :map)
      add(:machine_name, :string)
    end

    create(index(:content_type_field, [:content_type_id, :order]))

    create(
      unique_index(:content_type_field, [:machine_name, :content_type_id],
        name: :content_type_field_machine_name_content_type_unique_index
      )
    )
  end

  def down do
    drop_if_exists(index(:content_type_field, [:content_type_id, :order]))

    drop_if_exists(
      unique_index(:content_type_field, [:machine_name, :content_type_id],
        name: :content_type_field_machine_name_content_type_unique_index
      )
    )

    alter table(:content_type_field) do
      remove(:order)
      remove(:validations)
      remove(:machine_name)
    end
  end
end
