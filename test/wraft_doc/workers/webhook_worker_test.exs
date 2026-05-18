defmodule WraftDoc.Workers.WebhookWorkerTest do
  use WraftDoc.DataCase

  alias WraftDoc.Webhooks.WebhookLog
  alias WraftDoc.Workers.WebhookWorker

  describe "generate_signature/2" do
    test "produces a deterministic HMAC-SHA256 signature for a known vector" do
      # Reference vector: HMAC-SHA256("key", "The quick brown fox jumps over the lazy dog")
      # = f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8
      assert "sha256=f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8" ==
               WebhookWorker.generate_signature(
                 "The quick brown fox jumps over the lazy dog",
                 "key"
               )
    end

    test "returns different signatures for different secrets" do
      body = ~s|{"event":"document.created"}|

      sig1 = WebhookWorker.generate_signature(body, "secret-a")
      sig2 = WebhookWorker.generate_signature(body, "secret-b")

      refute sig1 == sig2
    end
  end

  describe "build_request/2" do
    test "non-Discord URL: signed envelope body and HMAC header" do
      webhook =
        build(:webhook,
          url: "https://example.com/hook",
          secret: "shh",
          headers: %{"X-Custom" => "v"}
        )

      payload = %{"event" => "document.created", "data" => %{}}

      assert {body, headers} = WebhookWorker.build_request(webhook, payload)

      # Envelope body, NOT Discord shape
      assert Jason.decode!(body) == payload

      headers_map = Map.new(headers)
      assert headers_map["Content-Type"] == "application/json"
      assert headers_map["User-Agent"] =~ "WraftDoc-Webhook"
      assert headers_map["X-Custom"] == "v"
      assert headers_map["X-WraftDoc-Signature"] =~ ~r/^sha256=[0-9a-f]{64}$/
    end

    test "Discord URL: Discord-shaped body with allowed_mentions, Content-Type-only headers" do
      webhook =
        build(:webhook,
          url: "https://discord.com/api/webhooks/123/abc",
          secret: "shh",
          headers: %{"X-Custom" => "v"}
        )

      payload = %{
        "event" => "document.created",
        "data" => %{"content" => "Hello"}
      }

      assert {body, headers} = WebhookWorker.build_request(webhook, payload)

      decoded = Jason.decode!(body)
      assert decoded["content"] == ""
      assert is_list(decoded["embeds"])
      # Mention-injection defence — must always be present.
      assert decoded["allowed_mentions"] == %{"parse" => []}

      # Only Content-Type — no signature, no custom headers, no User-Agent.
      # This must match what's logged in the audit row.
      assert headers == [{"Content-Type", "application/json"}]
    end
  end

  describe "perform/1" do
    test "returns :ok and skips delivery when webhook is inactive" do
      webhook = insert(:webhook, is_active: false)

      assert :ok =
               perform_job(WebhookWorker, %{
                 "webhook_id" => webhook.id,
                 "event" => "document.created",
                 "payload" => %{"event" => "document.created", "data" => %{}}
               })

      assert Repo.aggregate(WebhookLog, :count) == 0
    end

    test "returns {:error, :webhook_not_found} when the webhook id does not exist" do
      assert {:error, :webhook_not_found} =
               perform_job(WebhookWorker, %{
                 "webhook_id" => Ecto.UUID.generate(),
                 "event" => "document.created",
                 "payload" => %{"event" => "document.created", "data" => %{}}
               })
    end

    test "returns {:error, :invalid_args} for malformed args" do
      assert {:error, :invalid_args} =
               perform_job(WebhookWorker, %{"unexpected" => true})
    end

    # Regression test for the bug where attempt_number always logged as 1
    # regardless of the actual Oban retry count.
    test "records the Oban job's attempt count in the log row" do
      # Port 1 is reserved/closed; the request fails fast with :econnrefused,
      # but the log row is written before the HTTP call.
      webhook = insert(:webhook, url: "http://127.0.0.1:1")

      perform_job(
        WebhookWorker,
        %{
          "webhook_id" => webhook.id,
          "event" => "document.created",
          "payload" => %{"event" => "document.created", "data" => %{}}
        },
        attempt: 4
      )

      [log] = Repo.all(WebhookLog)
      assert log.attempt_number == 4
      refute log.success
    end

    # Audit-log accuracy: the request_headers column must match what was
    # actually sent on the wire. discord_webhook?/1 uses substring matching,
    # so the URL contains "discord.com/api/webhooks/" in its path while still
    # pointing at a closed local port — avoids a real outgoing call.
    test "logs Content-Type-only headers for Discord deliveries" do
      webhook =
        insert(:webhook,
          url: "http://127.0.0.1:1/discord.com/api/webhooks/123/abc",
          secret: "shh"
        )

      perform_job(WebhookWorker, %{
        "webhook_id" => webhook.id,
        "event" => "document.created",
        "payload" => %{"event" => "document.created", "data" => %{}}
      })

      [log] = Repo.all(WebhookLog)
      assert log.request_headers == %{"Content-Type" => "application/json"}
      refute Map.has_key?(log.request_headers, "X-WraftDoc-Signature")
    end
  end
end
