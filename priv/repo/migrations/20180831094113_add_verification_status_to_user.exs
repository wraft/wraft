defmodule ExStarter.Repo.Migrations.AddVerificationStatusToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:mobile_verify, :boolean, default: false)
      add(:email_verify, :boolean, default: false)
    end
  end
end
