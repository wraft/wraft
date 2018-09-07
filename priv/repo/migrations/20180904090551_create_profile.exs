defmodule Starter.Repo.Migrations.CreateProfile do
  use Ecto.Migration

  def change do
    create table(:basic_profile) do
      add :dob, :date
      add :gender, :string
      add :marital_status, :string
      add :current_location, :string
      add :address, :string
      add :pin, :string
      add :user_id, references(:users), null: false

      timestamps()
    end
    create unique_index(:basic_profile, [:user_id])
  end
end
