defmodule WraftDoc.AiAgents.ToolIntegrationTest do
  @moduledoc """
  Exercises the full AI tool path against a fake OpenAI-compatible server,
  covering the llamacpp provider route (openai provider + custom base_url).
  """
  use WraftDoc.DataCase

  alias WraftDoc.AiAgents.ResponseModel.Refinement
  alias WraftDoc.AiAgents.Tools.DocRefinement
  alias WraftDoc.Models.ModelLog

  setup do
    bypass = Bypass.open()
    user = insert(:user_with_organisation)

    model = %{
      model_name: "llama-3.1-8b",
      provider: "llamacpp",
      auth_key: "test-key",
      endpoint_url: "http://localhost:#{bypass.port}/v1"
    }

    %{bypass: bypass, user: user, model: model}
  end

  test "runs a tool against an OpenAI-compatible endpoint and logs the call", %{
    bypass: bypass,
    user: user,
    model: model
  } do
    Bypass.expect(bypass, "POST", "/v1/chat/completions", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      assert payload["model"] == "llama-3.1-8b"
      assert ["Bearer test-key"] = Plug.Conn.get_req_header(conn, "authorization")

      response = %{
        id: "chatcmpl-test",
        object: "chat.completion",
        created: 0,
        model: "llama-3.1-8b",
        choices: [
          %{
            index: 0,
            message: %{
              role: "assistant",
              content: Jason.encode!(%{refined_content: "Polished text"})
            },
            finish_reason: "stop"
          }
        ],
        usage: %{prompt_tokens: 10, completion_tokens: 5, total_tokens: 15}
      }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)

    params = %{
      model: model,
      prompt: %{prompt: "Refine this document"},
      content: "Some draft content",
      user: user
    }

    assert {:ok, %Refinement{refined_content: "Polished text"}} = DocRefinement.run(params, %{})

    assert [%ModelLog{status: "success", provider: "llamacpp"} = log] = Repo.all(ModelLog)
    assert log.endpoint == "http://localhost:#{bypass.port}/v1"
  end

  test "retries a retryable 5xx and succeeds on a later attempt", %{
    bypass: bypass,
    user: user,
    model: model
  } do
    {:ok, attempts} = Agent.start_link(fn -> 0 end)

    Bypass.expect(bypass, "POST", "/v1/chat/completions", fn conn ->
      n = Agent.get_and_update(attempts, &{&1, &1 + 1})

      if n < 2 do
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(503, Jason.encode!(%{error: %{message: "overloaded"}}))
      else
        response = %{
          id: "chatcmpl-test",
          object: "chat.completion",
          created: 0,
          model: "llama-3.1-8b",
          choices: [
            %{
              index: 0,
              message: %{
                role: "assistant",
                content: Jason.encode!(%{refined_content: "Polished text"})
              },
              finish_reason: "stop"
            }
          ],
          usage: %{prompt_tokens: 10, completion_tokens: 5, total_tokens: 15}
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end
    end)

    params = %{
      model: model,
      prompt: %{prompt: "Refine this document"},
      content: "Some draft content",
      user: user
    }

    assert {:ok, %Refinement{refined_content: "Polished text"}} = DocRefinement.run(params, %{})
    # two 503s retried, third attempt succeeded
    assert Agent.get(attempts, & &1) == 3
    assert [%ModelLog{status: "success"}] = Repo.all(ModelLog)
  end

  test "returns formatted error without retrying when the provider rejects the key", %{
    bypass: bypass,
    user: user,
    model: model
  } do
    # expect_once asserts the deterministic 401 is NOT retried
    Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
      error_body = %{error: %{message: "invalid api key", type: "auth_error"}}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(error_body))
    end)

    params = %{
      model: model,
      prompt: %{prompt: "Refine this document"},
      content: "Some draft content",
      user: user
    }

    assert {:error, _reason} = DocRefinement.run(params, %{})
    assert [%ModelLog{status: "failed"}] = Repo.all(ModelLog)
  end

  test "returns an error instead of crashing when the response is not parseable", %{
    bypass: bypass,
    user: user,
    model: model
  } do
    Bypass.expect(bypass, "POST", "/v1/chat/completions", fn conn ->
      response = %{
        id: "chatcmpl-test",
        object: "chat.completion",
        created: 0,
        model: "llama-3.1-8b",
        choices: [
          %{
            index: 0,
            message: %{role: "assistant", content: "I am not JSON at all"},
            finish_reason: "stop"
          }
        ],
        usage: %{prompt_tokens: 10, completion_tokens: 5, total_tokens: 15}
      }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)

    params = %{
      model: model,
      prompt: %{prompt: "Refine this document"},
      content: "Some draft content",
      user: user
    }

    assert {:error, "The AI model returned an unreadable response, please try again"} =
             DocRefinement.run(params, %{})

    assert [%ModelLog{status: "failed"}] = Repo.all(ModelLog)
  end

  test "returns error for unsupported provider without calling any endpoint", %{user: user} do
    params = %{
      model: %{
        model_name: "x",
        provider: "unknown_provider",
        auth_key: "k",
        endpoint_url: nil
      },
      prompt: %{prompt: "Refine"},
      content: "content",
      user: user
    }

    assert {:error, "Unsupported AI provider: unknown_provider"} =
             DocRefinement.run(params, %{})
  end
end
