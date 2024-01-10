defmodule WraftDoc.Repo.Migrations.AddUniqueIndexForPrefixInFormTable do
  use Ecto.Migration

  def change do
    create(unique_index(:form, [:prefix, :organisation_id], name: :form_prefix_unique_index))
  end
end
