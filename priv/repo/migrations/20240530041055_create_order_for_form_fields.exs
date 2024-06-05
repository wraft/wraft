defmodule WraftDoc.Repo.Migrations.CreateOrderForFormFields do
  use Ecto.Migration

  def change do
    alter table(:form_field) do
      add(:order, :integer)
    end
  end
end
