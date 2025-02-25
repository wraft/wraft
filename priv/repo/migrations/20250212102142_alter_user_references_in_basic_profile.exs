defmodule WraftDoc.Repo.Migrations.AlterUserReferencesInBasicProfile do
  use Ecto.Migration

  def up do
    drop(constraint("basic_profile", "basic_profile_user_id_fkey"))

    alter table(:basic_profile) do
      modify(:user_id, references(:user, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )
    end

    drop(constraint("subscriptions", "subscriptions_plan_id_fkey"))
    drop(constraint("subscriptions", "subscriptions_organisation_id_fkey"))
    drop(constraint("subscriptions", "subscriptions_subscriber_id_fkey"))

    alter table(:subscriptions) do
      modify(:plan_id, references(:plan, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )

      modify(
        :subscriber_id,
        references(:user, type: :uuid, column: :id, on_delete: :nilify_all)
      )
    end
  end

  def down do
    drop(constraint("basic_profile", "basic_profile_user_id_fkey"))

    alter table(:basic_profile) do
      modify(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )
    end

    drop(constraint("subscriptions", "subscriptions_plan_id_fkey"))
    drop(constraint("subscriptions", "subscriptions_organisation_id_fkey"))
    drop(constraint("subscriptions", "subscriptions_subscriber_id_fkey"))

    alter table(:subscriptions) do
      modify(:plan_id, references(:plan, type: :uuid, column: :id, on_delete: :nothing),
        null: false
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nothing),
        null: false
      )

      modify(:subscriber_id, references(:user, type: :uuid, column: :id, on_delete: :nothing))
    end
  end
end
