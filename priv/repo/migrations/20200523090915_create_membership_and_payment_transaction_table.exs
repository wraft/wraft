defmodule WraftDoc.Repo.Migrations.CreateMembershipAndPaymentTransactionTable do
  use Ecto.Migration

  def up do
    create table(:membership) do
      add(:uuid, :uuid, null: false)
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
      add(:plan_id, references(:plan, on_delete: :nilify_all))
      add(:start_date, :naive_datetime)
      add(:end_date, :naive_datetime)
      add(:plan_duration, :integer)

      timestamps()
    end

    create table(:payment) do
      add(:uuid, :uuid, null: false)
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
      add(:creator_id, references(:user, on_delete: :nilify_all))
      add(:membership_id, references(:membership, on_delete: :nilify_all))
      add(:razorpay_id, :string, null: false)
      add(:start_date, :naive_datetime)
      add(:end_date, :naive_datetime)
      add(:invoice, :string)
      add(:invoice_number, :string)
      add(:amount, :float, default: 0.0)
      add(:action, :integer)
      add(:from_plan_id, references(:plan, on_delete: :nilify_all))
      add(:to_plan_id, references(:plan, on_delete: :nilify_all))
      add(:status, :integer, null: false)
      timestamps()
    end

    create(unique_index(:membership, [:organisation_id], name: :membership_unique_index))
    create(unique_index(:payment, [:razorpay_id], name: :razorpay_id_unique_index))
    create(unique_index(:payment, [:invoice_number], name: :invoice_number_unique_index))
  end

  def down do
    drop_if_exists(table(:payment))
    drop_if_exists(table(:membership))
  end
end
