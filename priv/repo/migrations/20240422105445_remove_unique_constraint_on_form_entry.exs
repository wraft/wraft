defmodule WraftDoc.Repo.Migrations.RemoveUniqueConstraintOnFormEntry do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:form_entry, [:user_id, :form_id], name: :user_form_unique_index))
  end
end
