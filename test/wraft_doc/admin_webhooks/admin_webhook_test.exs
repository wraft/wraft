defmodule WraftDoc.AdminWebhooks.AdminWebhookTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory

  alias WraftDoc.AdminWebhooks.AdminWebhook

  @valid_params %{
    "name" => "Test Admin Webhook",
    "url" => "https://example.com/hook",
    "events" => ["admin.user.created", "admin.test"],
    "secret" => "shhh",
    "retry_count" => 3,
    "timeout_seconds" => 30
  }

  describe "changeset/2" do
    test "is valid with valid params" do
      changeset = AdminWebhook.changeset(%AdminWebhook{}, @valid_params)
      assert changeset.valid?
    end

    test "requires name and url" do
      changeset = AdminWebhook.changeset(%AdminWebhook{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :name)
      assert "can't be blank" in errors_on(changeset, :url)
    end

    test "rejects unknown events" do
      params = Map.put(@valid_params, "events", ["admin.user.created", "made.up.event"])
      changeset = AdminWebhook.changeset(%AdminWebhook{}, params)

      refute changeset.valid?
      assert "contains invalid events: made.up.event" in errors_on(changeset, :events)
    end

    test "rejects non-http(s) urls" do
      params = Map.put(@valid_params, "url", "ftp://example.com/x")
      changeset = AdminWebhook.changeset(%AdminWebhook{}, params)

      refute changeset.valid?
      assert "must be a valid HTTP or HTTPS URL" in errors_on(changeset, :url)
    end

    test "rejects malformed urls" do
      params = Map.put(@valid_params, "url", "not a url")
      changeset = AdminWebhook.changeset(%AdminWebhook{}, params)

      refute changeset.valid?
      assert "must be a valid HTTP or HTTPS URL" in errors_on(changeset, :url)
    end

    test "rejects non-positive retry_count" do
      params = Map.put(@valid_params, "retry_count", 0)
      changeset = AdminWebhook.changeset(%AdminWebhook{}, params)

      refute changeset.valid?
      assert "must be a positive integer" in errors_on(changeset, :retry_count)
    end

    test "rejects non-positive timeout_seconds" do
      params = Map.put(@valid_params, "timeout_seconds", -1)
      changeset = AdminWebhook.changeset(%AdminWebhook{}, params)

      refute changeset.valid?
      assert "must be a positive integer" in errors_on(changeset, :timeout_seconds)
    end
  end

  describe "update_changeset/2" do
    test "ignores creator_id changes" do
      webhook = insert(:admin_webhook)

      changeset =
        AdminWebhook.update_changeset(webhook, %{
          "creator_id" => Ecto.UUID.generate(),
          "name" => "Renamed"
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :creator_id)
      assert changeset.changes.name == "Renamed"
    end
  end

  describe "admin_webhook_events/0" do
    test "returns the whitelisted event list" do
      events = AdminWebhook.admin_webhook_events()

      assert "admin.user.created" in events
      assert "admin.organisation.deleted" in events
      assert "admin.waiting_list.approved" in events
      assert "admin.waiting_list.confirmation_email_sent" in events
      assert "admin.test" in events
    end
  end
end
