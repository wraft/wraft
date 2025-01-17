defmodule WraftDoc.Repo.Migrations.ChangeNotificationScope do
  use Ecto.Migration

  def change do
    alter table(:notification) do
      remove(:is_global)
      add(:scope, :string, default: "user")
    end
  end
end
