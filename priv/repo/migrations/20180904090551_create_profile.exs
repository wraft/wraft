defmodule ExStarter.Repo.Migrations.CreateProfile do
  use Ecto.Migration

  def change do
    create table(:basic_profile) do
      add(:name, :string, null: false)
      add(:dob, :date)
      add(:gender, :string)
      add(:user_id, references(:user), null: false)
      add(:profile_pic, :string)
      timestamps()
    end

    create(unique_index(:basic_profile, [:user_id]))
  end
end
