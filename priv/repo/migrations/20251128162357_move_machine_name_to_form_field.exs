defmodule WraftDoc.Repo.Migrations.MoveMachineNameToFormField do
  use Ecto.Migration

  def up do
    alter table(:form_field) do
      add(:machine_name, :string)
    end

    create(
      unique_index(:form_field, [:machine_name, :form_id],
        name: :form_field_machine_name_form_unique_index
      )
    )

    drop_if_exists(
      unique_index(:field, [:machine_name, :organisation_id],
        name: :field_machine_name_organisation_unique_index
      )
    )

    alter table(:field) do
      remove_if_exists(:machine_name, :string)
    end
  end

  def down do
    drop_if_exists(
      unique_index(:form_field, [:machine_name, :form_id],
        name: :form_field_machine_name_form_unique_index
      )
    )

    alter table(:form_field) do
      remove_if_exists(:machine_name, :string)
    end

    alter table(:field) do
      add(:machine_name, :string)
    end

    create(
      unique_index(:field, [:machine_name, :organisation_id],
        name: :field_machine_name_organisation_unique_index
      )
    )
  end
end
