defmodule WraftDoc.Repo.Migrations.RemovedRepoCloudsTokens do
  use Ecto.Migration

  def change do
    drop(table(:repository_cloud_tokens))
  end
end
