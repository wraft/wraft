defmodule WraftDoc.Repo.Migrations.UpdateFormFieldTableAddMachineNameField do
  use Ecto.Migration

  def up do
    alter table(:form_field) do
      add(:machine_name, :string)
    end

    create(
      unique_index(:form_field, [:form_id, :machine_name],
        name: :form_machine_name_unique_per_form
      )
    )
  end

  def down do
    drop(index(:form_field, [:form_id, :machine_name], name: :form_machine_name_unique_per_form))

    alter table(:form_field) do
      remove(:machine_name)
    end
  end
end
