defmodule WraftDoc.Repo.Migrations.CreatePlansTable do
  use Ecto.Migration

  def up do
    create table(:plan) do
      add(:uuid, :uuid, null: false)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:yearly_amount, :integer, default: 0)
      add(:monthly_amount, :integer, default: 0)

      timestamps()
    end

    create(unique_index(:plan, [:name], name: :plan_unique_index))
  end

  def down do
    drop_if_exists(table(:plan))
  end
end
