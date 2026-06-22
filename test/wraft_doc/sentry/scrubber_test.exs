defmodule WraftDoc.Sentry.ScrubberTest do
  use ExUnit.Case, async: false

  alias WraftDoc.Sentry.Scrubber

  test "redacts the database URL and its password from event fields" do
    database_url = System.get_env("DATABASE_URL")
    assert is_binary(database_url)

    event = %{
      message: "connect failed for #{database_url}",
      exception: [%{type: "DBConnection.ConnectionError", value: "auth with #{database_url}"}],
      extra: %{"context" => "url was #{database_url}"}
    }

    scrubbed = Scrubber.scrub(event)

    refute scrubbed.message =~ database_url
    assert scrubbed.message =~ "[REDACTED]"
    refute hd(scrubbed.exception).value =~ database_url
    refute scrubbed.extra["context"] =~ database_url
  end

  test "leaves events without secrets untouched" do
    event = %{message: "plain error", exception: [], extra: %{}}

    assert Scrubber.scrub(event) == event
  end
end
