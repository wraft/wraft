defmodule WraftDoc.Repo.Migrations.CreateOrderForFormFields do
  use Ecto.Migration

  def change do
    alter table(:form_field) do
      add(:order, :integer)
    end

    create(unique_index(:form_field, [:order, :field_id]))
  end
end
