defmodule WraftDoc.Repo.Migrations.AddEndpointDetails do
  use Ecto.Migration

  def change do
    alter table(:block) do
      add(:api_route, :string)
      add(:endpoint, :string)
    end
  end
end
