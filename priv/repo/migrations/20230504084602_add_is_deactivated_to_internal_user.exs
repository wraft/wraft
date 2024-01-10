defmodule WraftDoc.Repo.Migrations.AddIsDeactivatedToInternalUser do
  use Ecto.Migration

  def change do
    alter table(:internal_user) do
      add(:is_deactivated, :boolean, default: false)
    end
  end
end
