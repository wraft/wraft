defmodule WraftDoc.Repo.Migrations.AddDeletedAtUser do
  use Ecto.Migration

  def change do
    add(:deleted_at, :naive_datetime)
  end
end
