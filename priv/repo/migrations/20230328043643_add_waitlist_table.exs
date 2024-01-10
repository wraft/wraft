defmodule WraftDoc.Repo.Migrations.AddWaitlistTable do
  use Ecto.Migration

  def change do
    create table(:waiting_list, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:first_name, :string)
      add(:last_name, :string)
      add(:email, :string)
      add(:status, :string)

      timestamps()
    end

    create(unique_index(:waiting_list, [:email]))
  end
end
