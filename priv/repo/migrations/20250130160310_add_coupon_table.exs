defmodule WraftDoc.Repo.Migrations.AddCouponTable do
  use Ecto.Migration

  def change do
    create table(:coupon, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:description, :string)
      add(:coupon_id, :string)
      add(:coupon_code, :string)
      add(:amount, :string)
      add(:currency, :string)
      add(:type, :string)
      add(:status, :string)
      add(:recurring, :boolean)
      add(:maximum_recurring_intervals, :integer)
      add(:expiry, :utc_datetime)
      add(:times_used, :integer)
      add(:usage_limit, :integer)

      timestamps()
    end

    create(index(:coupon, [:coupon_id]))
    create(unique_index(:coupon, [:name], name: :coupon_name_index))
    create(unique_index(:coupon, [:coupon_code], name: :coupon_code_index))

    alter table(:plan) do
      add(:coupon_id, references(:coupon, on_delete: :nothing, type: :uuid))
    end
  end
end
