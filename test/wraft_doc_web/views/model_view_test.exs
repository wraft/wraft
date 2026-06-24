defmodule WraftDocWeb.Api.V1.ModelViewTest do
  @moduledoc """
  mask_auth_key/1 must mask the stored key for display without crashing on
  short keys (String.duplicate/2 raises on a negative count).
  """
  use ExUnit.Case, async: true

  alias WraftDoc.Models.Model
  alias WraftDocWeb.Api.V1.ModelView

  defp model(auth_key) do
    %Model{
      id: "11111111-1111-1111-1111-111111111111",
      name: "Test",
      description: "desc",
      provider: "openai",
      model_name: "gpt-4o-mini",
      model_type: "text",
      model_version: "1.0",
      endpoint_url: nil,
      is_default: false,
      is_local: false,
      is_thinking_model: false,
      daily_request_limit: 1000,
      daily_token_limit: 100_000,
      auth_key: auth_key,
      status: "active"
    }
  end

  test "masks a normal-length key, revealing only the last 4 chars" do
    # 12-char key -> 8 masked + last 4 visible
    assert %{data: %{auth_key: "********wxyz"}} =
             ModelView.show(%{model: model("abcdefghwxyz")})
  end

  test "fully masks a key of 4 bytes or fewer without raising" do
    assert %{data: %{auth_key: "**"}} = ModelView.show(%{model: model("ab")})
    assert %{data: %{auth_key: "****"}} = ModelView.show(%{model: model("abcd")})
  end

  test "passes through nil and the decryption-error marker" do
    assert %{data: %{auth_key: nil}} = ModelView.show(%{model: model(nil)})

    assert %{data: %{auth_key: %{"error" => _}}} =
             ModelView.show(%{model: model(:error)})
  end
end
