defmodule WraftDoc.Repo.Migrations.AddCouponTable do
  use Ecto.Migration

  def up do
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
      add(:start_date, :utc_datetime)
      add(:expiry_date, :utc_datetime)
      add(:times_used, :integer)
      add(:usage_limit, :integer)

      timestamps()
    end

    create(index(:coupon, [:coupon_id]))
    create(unique_index(:coupon, [:name], name: :coupon_name_index))
    create(unique_index(:coupon, [:coupon_code], name: :coupon_code_index))

    alter table(:plan) do
      add(:coupon_id, references(:coupon, on_delete: :nothing, type: :uuid))
      rename(:pay_link, to: :payment_link)
    end

    alter table(:subscriptions) do
      remove(:type)
      add(:coupon_id, references(:coupon, on_delete: :nothing, type: :uuid))
      add(:coupon_start_date, :utc_datetime)
      add(:coupon_end_date, :utc_datetime)
    end

    alter table(:transaction) do
      add(:discount_amount, :string)
      add(:coupon_id, references(:coupon, on_delete: :nothing, type: :uuid))
    end
  end

  def down do
    alter table(:transaction) do
      remove(:discount_amount)
      remove(:coupon_id)
    end

    alter table(:subscriptions) do
      remove(:coupon_end_date)
      remove(:coupon_start_date)
      remove(:coupon_id)
      add(:type, :string)
    end

    alter table(:plan) do
      remove(:coupon_id)
      rename(:payment_link, to: :pay_link)
    end

    drop(index(:coupon, [:coupon_id]))
    drop(unique_index(:coupon, [:name], name: :coupon_name_index))
    drop(unique_index(:coupon, [:coupon_code], name: :coupon_code_index))

    drop(table(:coupon))
  end
end
