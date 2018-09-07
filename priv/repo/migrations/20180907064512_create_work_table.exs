defmodule Starter.Repo.Migrations.CreateWorkTable do
  use Ecto.Migration

  def change do
    create table(:works) do
      add :company, :string, null: false
      add :location, :string, null: false
      add :designation, :string, null: false
      add :from_date, :date, null: false
      add :to_date, :date
      add :description, :string
      add :file, :string
      add :days_worked, :integer, null: false
      add :current_job, :boolean, default: false
      add :user_id, references(:users)

      timestamps()
    end    
  end
end
