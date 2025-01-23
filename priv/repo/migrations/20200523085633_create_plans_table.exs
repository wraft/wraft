defmodule WraftDoc.Repo.Migrations.CreatePlansTable do
  use Ecto.Migration

  alias WraftDoc.DeploymentMode

  if DeploymentMode.saas?() do
    def up do
      create table(:plan, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add(:name, :string, null: false)
        add(:description, :text)
        add(:yearly_amount, :integer, default: 0)
        add(:monthly_amount, :integer, default: 0)

        timestamps()
      end
    end

    def down do
      drop_if_exists(table(:plan))
    end
  end
end
