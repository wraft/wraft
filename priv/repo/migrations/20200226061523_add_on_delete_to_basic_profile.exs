defmodule WraftDoc.Repo.Migrations.AddOnDeleteToBasicProfile do
  use Ecto.Migration

  def up do
    drop(constraint(:basic_profile, "basic_profile_user_id_fkey"))

    alter table(:basic_profile) do
      modify(:user_id, references(:user, on_delete: :delete_all))
    end
  end

  def down do
    drop(constraint(:basic_profile, "basic_profile_user_id_fkey"))

    alter table(:basic_profile) do
      modify(:user_id, references(:user))
    end
  end
end
