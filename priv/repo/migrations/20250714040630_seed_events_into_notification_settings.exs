defmodule WraftDoc.Repo.Migrations.SeedEventsIntoNotificationSettings do
  use Ecto.Migration

  import Ecto.Query

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Notifications.Template
  alias WraftDoc.Repo

  def up do
    events = Template.list_notification_types()

    organisations =
      Organisation
      |> select([o], o.id)
      |> Repo.all()

    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    for organisation_id <- organisations do
      {:ok, organisation_id} = Ecto.UUID.dump(organisation_id)
      execute_insert(organisation_id, events, now)
    end
  end

  def down do
    execute("DELETE FROM notification_settings")
  end

  defp execute_insert(organisation_id, events, now) do
    {:ok, id} = Ecto.UUID.dump(Ecto.UUID.generate())

    Repo.insert_all("notification_settings", [
      %{
        id: id,
        organisation_id: organisation_id,
        events: events,
        inserted_at: now,
        updated_at: now
      }
    ])
  end
end
