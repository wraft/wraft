defmodule WraftDoc.Repo.Migrations.AddSignedFileToCounterParties do
  use Ecto.Migration

  def change do
    alter table(:counter_parties) do
      add(:signed_file, :string)
    end

    drop_if_exists(unique_index(:counter_parties, [:content_id]))
  end
end
