defmodule WraftDoc.Repo.Migrations.CounterPartyMailSendStatus do
  use Ecto.Migration

  def change do
    alter table(:counter_parties) do
      add(:mail_send_status, :boolean, null: false, default: false)
    end
  end
end
