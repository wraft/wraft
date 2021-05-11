defmodule WraftDoc.Repo.Migrations.CreateProfile do
  use Ecto.Migration

  def change do
    create table(:basic_profile, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:dob, :date)
      add(:gender, :string)

      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )

      add(:profile_pic, :string)
      timestamps()
    end

    create(unique_index(:basic_profile, [:user_id]))
  end
end
