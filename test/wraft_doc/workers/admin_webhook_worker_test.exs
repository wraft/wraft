defmodule WraftDoc.Workers.AdminWebhookWorkerTest do
  use WraftDoc.DataCase

  alias WraftDoc.AdminWebhooks.AdminWebhookLog
  alias WraftDoc.Workers.AdminWebhookWorker

  describe "generate_signature/2" do
    test "produces a deterministic HMAC-SHA256 signature for a known vector" do
      # Reference vector: HMAC-SHA256("key", "The quick brown fox jumps over the lazy dog")
      # = f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8
      assert "sha256=f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8" ==
               AdminWebhookWorker.generate_signature(
                 "The quick brown fox jumps over the lazy dog",
                 "key"
               )
    end

    test "returns different signatures for different secrets" do
      body = ~s|{"event":"admin.test"}|

      sig1 = AdminWebhookWorker.generate_signature(body, "secret-a")
      sig2 = AdminWebhookWorker.generate_signature(body, "secret-b")

      refute sig1 == sig2
    end
  end

  describe "format_discord_payload/1" do
    test "renders user.updated as a sentence including the actor" do
      payload = %{
        "event" => "admin.user.updated",
        "timestamp" => "2026-05-15T12:00:00Z",
        "actor" => %{"id" => "i1", "email" => "ops@wraft.test"},
        "data" => %{
          "user" => %{"id" => "u1", "name" => "Alice", "email" => "a@x"},
          "action" => "updated"
        }
      }

      assert %{content: "", embeds: [embed]} =
               AdminWebhookWorker.format_discord_payload(payload)

      # Blue for *.updated
      assert embed.color == 3_447_003
      assert embed.title == "👤 User updated"
      assert embed.timestamp == "2026-05-15T12:00:00Z"
      assert embed.description == "**Alice** (a@x) was updated by **ops@wraft.test**."
      # Resource id is a field for traceability, but not in the description.
      assert %{name: "ID", value: "u1", inline: true} in embed.fields
      assert %{name: "Event", value: "admin.user.updated", inline: true} in embed.fields
    end

    test "renders organisation.deleted as 'soft-deleted' when soft_deleted is true" do
      payload = %{
        "event" => "admin.organisation.deleted",
        "actor" => %{"email" => "ops@wraft.test"},
        "data" => %{
          "organisation" => %{"id" => "o1", "name" => "Acme"},
          "action" => "deleted",
          "soft_deleted" => true
        }
      }

      assert %{embeds: [embed]} = AdminWebhookWorker.format_discord_payload(payload)
      assert embed.color == 15_158_332
      assert embed.title == "🏢 Organisation deleted"

      assert embed.description ==
               "Organisation **Acme** was soft-deleted by **ops@wraft.test**."
    end

    test "renders waiting_list.approved with party emoji and approval copy" do
      payload = %{
        "event" => "admin.waiting_list.approved",
        "actor" => %{"email" => "ops@wraft.test"},
        "data" => %{
          "waiting_list" => %{
            "id" => "w1",
            "first_name" => "Bob",
            "last_name" => "X",
            "email" => "bob@x",
            "status" => "approved"
          },
          "action" => "approved"
        }
      }

      assert %{embeds: [embed]} = AdminWebhookWorker.format_discord_payload(payload)
      assert embed.color == 15_844_367
      assert embed.title == "🎉 Waiting list entry approved"
      assert embed.description =~ "**Bob X** (bob@x) was approved by **ops@wraft.test**"
      assert embed.description =~ "set-password email"
    end

    test "omits actor phrase when no actor is provided" do
      payload = %{
        "event" => "admin.waiting_list.created",
        "data" => %{
          "waiting_list" => %{
            "id" => "w2",
            "first_name" => "Cara",
            "last_name" => "Z",
            "email" => "cara@x",
            "status" => "pending"
          }
        }
      }

      assert %{embeds: [embed]} = AdminWebhookWorker.format_discord_payload(payload)
      assert embed.description == "**Cara Z** (cara@x) joined the waiting list."
    end

    test "renders waiting_list.confirmation_email_sent with envelope emoji" do
      payload = %{
        "event" => "admin.waiting_list.confirmation_email_sent",
        "data" => %{
          "waiting_list" => %{
            "id" => "w3",
            "first_name" => "Dee",
            "last_name" => "Q",
            "email" => "dee@x",
            "status" => "pending"
          },
          "action" => "confirmation_email_sent"
        }
      }

      assert %{embeds: [embed]} = AdminWebhookWorker.format_discord_payload(payload)
      assert embed.title == "✉️ Waiting list confirmation email sent"
      assert embed.description == "Confirmation email queued for **Dee Q** (dee@x)."
    end

    test "falls back to the message field for the test event" do
      payload = %{
        "event" => "admin.test",
        "data" => %{"message" => "This is a test admin webhook event."}
      }

      assert %{embeds: [embed]} = AdminWebhookWorker.format_discord_payload(payload)
      assert embed.title == "🧪 Test event"
      assert embed.description == "This is a test admin webhook event."
    end

    # Defence against mention injection: a user named "@everyone" must not be
    # able to ping the entire Discord server when their event is delivered.
    test "always sets allowed_mentions to disable @everyone/@here parsing" do
      payload = %{
        "event" => "admin.user.created",
        "data" => %{
          "user" => %{
            "id" => "u1",
            "name" => "Mallory @everyone",
            "email" => "evil@x"
          }
        }
      }

      assert %{allowed_mentions: %{parse: []}, embeds: [embed]} =
               AdminWebhookWorker.format_discord_payload(payload)

      # The hostile name still appears in the description (so admins can see
      # what was attempted), but Discord won't process the @everyone token.
      assert embed.description =~ "Mallory @everyone"
    end
  end

  describe "build_request/2" do
    test "non-Discord URL: signed envelope body and HMAC header" do
      webhook =
        build(:admin_webhook,
          url: "https://example.com/hook",
          secret: "shh",
          headers: %{"X-Custom" => "v"}
        )

      payload = %{"event" => "admin.test", "data" => %{}}

      assert {body, headers} = AdminWebhookWorker.build_request(webhook, payload)

      # Envelope body, NOT Discord shape
      assert Jason.decode!(body) == payload

      headers_map = Map.new(headers)
      assert headers_map["Content-Type"] == "application/json"
      assert headers_map["User-Agent"] =~ "WraftDoc-Admin-Webhook"
      assert headers_map["X-Custom"] == "v"
      assert headers_map["X-WraftDoc-Admin-Signature"] =~ ~r/^sha256=[0-9a-f]{64}$/
    end

    test "Discord URL: Discord-shaped body and Content-Type-only headers" do
      webhook =
        build(:admin_webhook,
          url: "https://discord.com/api/webhooks/123/abc",
          secret: "shh",
          headers: %{"X-Custom" => "v"}
        )

      payload = %{
        "event" => "admin.test",
        "data" => %{"message" => "hi"}
      }

      assert {body, headers} = AdminWebhookWorker.build_request(webhook, payload)

      # Discord shape, not the canonical envelope
      decoded = Jason.decode!(body)
      assert decoded["content"] == ""
      assert is_list(decoded["embeds"])
      assert decoded["allowed_mentions"] == %{"parse" => []}

      # Only Content-Type — no signature, no custom headers, no User-Agent.
      # This must match what we put in `request_headers` in the audit log.
      assert headers == [{"Content-Type", "application/json"}]
    end
  end

  describe "perform/1" do
    test "returns :ok and skips delivery when webhook is inactive" do
      webhook = insert(:admin_webhook, is_active: false)

      assert :ok =
               perform_job(AdminWebhookWorker, %{
                 "webhook_id" => webhook.id,
                 "event" => "admin.test",
                 "payload" => %{"event" => "admin.test", "data" => %{}}
               })

      # Confirm no log was written for the skipped delivery.
      assert WraftDoc.Repo.aggregate(WraftDoc.AdminWebhooks.AdminWebhookLog, :count) == 0
    end

    test "returns {:error, :webhook_not_found} when the webhook id does not exist" do
      assert {:error, :webhook_not_found} =
               perform_job(AdminWebhookWorker, %{
                 "webhook_id" => Ecto.UUID.generate(),
                 "event" => "admin.test",
                 "payload" => %{"event" => "admin.test", "data" => %{}}
               })
    end

    test "returns {:error, :invalid_args} for malformed args" do
      assert {:error, :invalid_args} =
               perform_job(AdminWebhookWorker, %{"unexpected" => true})
    end

    # Regression test for the bug where attempt_number always logged as 1
    # regardless of the actual Oban retry count.
    test "records the Oban job's attempt count in the log row" do
      # Port 1 is reserved/closed; the request fails fast with :econnrefused,
      # but the log row is written before the HTTP call.
      webhook = insert(:admin_webhook, url: "http://127.0.0.1:1")

      perform_job(
        AdminWebhookWorker,
        %{
          "webhook_id" => webhook.id,
          "event" => "admin.test",
          "payload" => %{"event" => "admin.test", "data" => %{}}
        },
        attempt: 3
      )

      [log] = Repo.all(AdminWebhookLog)
      assert log.attempt_number == 3
      refute log.success
    end
  end
end
