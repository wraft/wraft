defmodule WraftDoc.Repo.Migrations.CounterParties do
  use Ecto.Migration

  def change do
    # TODO  need to improve
    create table(:counter_parties, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)

      add(:content_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    create(unique_index(:counter_parties, [:content_id]))
  end
end
