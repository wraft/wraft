defmodule WraftDoc.Repo.Migrations.AddDeviceToCounterparty do
  use Ecto.Migration

  def change do
    alter table(:counter_parties) do
      add(:device, :string)
    end
  end
end
