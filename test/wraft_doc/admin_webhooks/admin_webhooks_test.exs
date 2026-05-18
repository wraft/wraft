defmodule WraftDoc.AdminWebhooksTest do
  use WraftDoc.DataCase

  alias WraftDoc.AdminWebhooks
  alias WraftDoc.AdminWebhooks.AdminWebhook
  alias WraftDoc.AdminWebhooks.AdminWebhookLog
  alias WraftDoc.Workers.AdminWebhookWorker

  describe "create_admin_webhook/2" do
    test "persists a webhook with the given internal_user as creator" do
      internal_user = insert(:internal_user)

      assert {:ok, %AdminWebhook{} = webhook} =
               AdminWebhooks.create_admin_webhook(internal_user.id, %{
                 "name" => "audit",
                 "url" => "https://example.com/h",
                 "events" => ["admin.user.created"]
               })

      assert webhook.creator_id == internal_user.id
      assert webhook.is_active
    end
  end

  describe "trigger_admin_webhooks/3" do
    test "enqueues one job per active subscriber to the event" do
      _matching = insert(:admin_webhook, events: ["admin.user.created", "admin.test"])
      _other_event = insert(:admin_webhook, events: ["admin.user.deleted"])
      _inactive = insert(:admin_webhook, events: ["admin.user.created"], is_active: false)

      assert :ok = AdminWebhooks.trigger_admin_webhooks("admin.user.created", %{user_id: "x"})

      assert_enqueued(worker: AdminWebhookWorker, args: %{"event" => "admin.user.created"})
      assert [_only_one] = all_enqueued(worker: AdminWebhookWorker)
    end

    test "is a no-op when no webhook subscribes to the event" do
      insert(:admin_webhook, events: ["admin.user.deleted"])

      assert :ok = AdminWebhooks.trigger_admin_webhooks("admin.user.created", %{})

      assert [] = all_enqueued(worker: AdminWebhookWorker)
    end

    test "embeds actor and event in the enqueued payload" do
      insert(:admin_webhook, events: ["admin.test"])
      actor = %{id: "abc", email: "admin@wraft.test"}

      AdminWebhooks.trigger_admin_webhooks("admin.test", %{message: "hi"}, actor)

      [%Oban.Job{args: args}] = all_enqueued(worker: AdminWebhookWorker)
      assert args["event"] == "admin.test"
      assert args["payload"]["event"] == "admin.test"
      assert args["payload"]["actor"] == %{"id" => "abc", "email" => "admin@wraft.test"}
      assert args["payload"]["data"] == %{"message" => "hi"}
    end
  end

  describe "create_admin_webhook_log/1" do
    test "inserts a log row with the supplied attributes" do
      webhook = insert(:admin_webhook)

      assert {:ok, %AdminWebhookLog{} = log} =
               AdminWebhooks.create_admin_webhook_log(%{
                 event: "admin.test",
                 url: webhook.url,
                 http_method: "POST",
                 request_headers: %{},
                 request_body: "{}",
                 attempt_number: 2,
                 triggered_at: DateTime.truncate(DateTime.utc_now(), :second),
                 webhook_id: webhook.id
               })

      assert log.attempt_number == 2
      assert log.webhook_id == webhook.id
    end
  end
end
