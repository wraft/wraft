defmodule WraftDoc.AiAgents.FormatErrorTest do
  @moduledoc """
  format_error/1 must always return a user-safe {:error, ...} tuple and never
  forward a non-integer / out-of-range provider code as an HTTP status.
  """
  use ExUnit.Case, async: true

  alias WraftDoc.AiAgents

  describe "format_error/1 with exception structs" do
    test "keeps an in-range integer status" do
      error = %ReqLLM.Error.API.Request{reason: "rate limited", status: 503}
      assert {:error, {503, %{errors: message}}} = AiAgents.format_error(error)
      assert is_binary(message)
    end

    test "drops a status outside 100..599 to a plain message tuple" do
      error = %ReqLLM.Error.API.Request{reason: "weird", status: 0}
      assert {:error, message} = AiAgents.format_error(error)
      assert is_binary(message)
    end

    test "an exception without a status returns its message" do
      assert {:error, message} = AiAgents.format_error(%RuntimeError{message: "boom"})
      assert message =~ "boom"
    end
  end

  describe "format_error/1 with binary messages" do
    test "decodes an embedded provider error with an in-range code" do
      msg = ~s(something %{"error" => %{"code" => 429, "message" => "slow down"}})
      assert {:error, {429, %{errors: "slow down"}}} = AiAgents.format_error(msg)
    end

    test "falls back to the message when the embedded code is out of range / non-integer" do
      msg = ~s(%{"error" => %{"code" => "BAD", "message" => "nope"}})
      assert {:error, "nope"} = AiAgents.format_error(msg)
    end

    test "returns a generic message for an undecodable binary" do
      assert {:error, "Something went wrong, please try again"} =
               AiAgents.format_error("connection refused")
    end
  end

  test "format_error/1 with an unexpected term returns a generic message" do
    assert {:error, "Something went wrong, please try again"} = AiAgents.format_error(nil)
  end
end
