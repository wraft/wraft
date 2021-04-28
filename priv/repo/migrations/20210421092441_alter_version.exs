defmodule WraftDoc.Repo.Migrations.AlterVersion do
  use Ecto.Migration

  def up do
    alter table(:version) do
      remove(:creator_id)
      add(:author_id, references(:user, on_delete: :nilify_all))
      add(:naration, :string)
    end
  end

  def down do
    alter table(:version) do
      remove(
        :author_id,
        add(:creator_id, references(:user, on_delete: :nilify_all))
      )

      remove(:naration)
    end
  end
end
