defmodule WraftDoc.Repo.Migrations.AddSignedInTimestamp do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:user) do
      add(:signed_in_at, :naive_datetime)
    end
  end
end
