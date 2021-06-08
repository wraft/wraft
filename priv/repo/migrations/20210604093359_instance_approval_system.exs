defmodule WraftDoc.Repo.Migrations.InstanceApprovalSystem do
  use Ecto.Migration

  def change do
    create table(:instance_approval_system, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:flag, :boolean, default: false)
      add(:order, :integer)
      add(:approved_at, :naive_datetime)
      add(:instance_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :approval_system_id,
        references(:approval_system, type: :uuid, column: :id, on_delete: :nilify_all)
      )
    end

    create(
      unique_index(:instance_approval_system, [:instance_id, :approval_system_id],
        name: :instance_approval_system_unique_constraint
      )
    )
  end
end
