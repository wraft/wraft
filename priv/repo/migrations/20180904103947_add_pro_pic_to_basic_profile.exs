defmodule ExStarter.Repo.Migrations.AddProPicToBasicProfile do
  use Ecto.Migration

  def change do
    alter table(:basic_profile) do
      add(:profile_pic, :string)
    end
  end
end
