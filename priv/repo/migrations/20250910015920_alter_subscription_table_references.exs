defmodule WraftDoc.Repo.Migrations.AlterSubscriptionTableReferences do
  use Ecto.Migration

  def up do
    alter table(:subscriptions) do
      modify(
        :subscriber_id,
        references(:user, type: :uuid, on_delete: :delete_all),
        from: references(:user, type: :uuid, on_delete: :nothing)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all),
        from: references(:organisation, type: :uuid, on_delete: :nothing)
      )

      modify(
        :plan_id,
        references(:plan, type: :uuid, on_delete: :delete_all),
        from: references(:plan, type: :uuid, on_delete: :nothing)
      )
    end

    alter table(:subscription_history) do
      modify(
        :subscriber_id,
        references(:user, type: :uuid, on_delete: :delete_all),
        from: references(:user, type: :uuid, on_delete: :nothing)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all),
        from: references(:organisation, type: :uuid, on_delete: :nothing)
      )

      modify(
        :plan_id,
        references(:plan, type: :uuid, on_delete: :delete_all),
        from: references(:plan, type: :uuid, on_delete: :nothing)
      )
    end

    alter table(:transaction) do
      modify(
        :subscriber_id,
        references(:user, type: :uuid, on_delete: :delete_all),
        from: references(:user, type: :uuid, on_delete: :nothing)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all),
        from: references(:organisation, type: :uuid, on_delete: :nothing)
      )

      modify(
        :plan_id,
        references(:plan, type: :uuid, on_delete: :delete_all),
        from: references(:plan, type: :uuid, on_delete: :nothing)
      )
    end

    alter table(:repositories) do
      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all),
        from: references(:organisation, type: :uuid, on_delete: :nothing)
      )
    end

    alter table(:storage_items) do
      modify(
        :repository_id,
        references(:repositories, type: :uuid, on_delete: :delete_all),
        from: references(:repositories, type: :uuid, on_delete: :nothing)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all),
        from: references(:organisation, type: :uuid, on_delete: :nothing)
      )
    end

    alter table(:storage_assets) do
      modify(
        :storage_item_id,
        references(:storage_items, type: :uuid, on_delete: :delete_all),
        from: references(:storage_items, type: :uuid, on_delete: :nothing)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :delete_all),
        from: references(:organisation, type: :uuid, on_delete: :nothing)
      )
    end
  end

  def down do
    alter table(:subscriptions) do
      modify(
        :subscriber_id,
        references(:user, type: :uuid, on_delete: :nothing),
        from: references(:user, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :nothing),
        from: references(:organisation, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :plan_id,
        references(:plan, type: :uuid, on_delete: :nothing),
        from: references(:plan, type: :uuid, on_delete: :delete_all)
      )
    end

    alter table(:subscription_history) do
      modify(
        :subscriber_id,
        references(:user, type: :uuid, on_delete: :nothing),
        from: references(:user, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :nothing),
        from: references(:organisation, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :plan_id,
        references(:plan, type: :uuid, on_delete: :nothing),
        from: references(:plan, type: :uuid, on_delete: :delete_all)
      )
    end

    alter table(:transaction) do
      modify(
        :subscriber_id,
        references(:user, type: :uuid, on_delete: :nothing),
        from: references(:user, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :nothing),
        from: references(:organisation, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :plan_id,
        references(:plan, type: :uuid, on_delete: :nothing),
        from: references(:plan, type: :uuid, on_delete: :delete_all)
      )
    end

    alter table(:repositories) do
      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :nothing),
        from: references(:organisation, type: :uuid, on_delete: :delete_all)
      )
    end

    alter table(:storage_items) do
      modify(
        :repository_id,
        references(:repositories, type: :uuid, on_delete: :nothing),
        from: references(:repositories, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :nothing),
        from: references(:organisation, type: :uuid, on_delete: :delete_all)
      )
    end

    alter table(:storage_assets) do
      modify(
        :storage_item_id,
        references(:storage_items, type: :uuid, on_delete: :nothing),
        from: references(:storage_items, type: :uuid, on_delete: :delete_all)
      )

      modify(
        :organisation_id,
        references(:organisation, type: :uuid, on_delete: :nothing),
        from: references(:organisation, type: :uuid, on_delete: :delete_all)
      )
    end
  end
end
