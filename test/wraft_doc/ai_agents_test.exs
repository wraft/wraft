defmodule WraftDoc.AiAgentsTest do
  use WraftDoc.DataCase

  alias WraftDoc.AiAgents

  describe "validate_params/1" do
    test "returns error when content is missing" do
      params = %{"prompt_id" => "some-id"}
      assert {:error, "Content is required"} = AiAgents.validate_params(params)
    end

    test "returns error when content is empty string" do
      params = %{"content" => "", "prompt_id" => "some-id"}
      assert {:error, "Content is required"} = AiAgents.validate_params(params)
    end

    test "returns error when both prompt_id and prompt are missing" do
      params = %{"content" => "some content"}

      assert {:error, "Either prompt_id or prompt with prompt_type is required"} =
               AiAgents.validate_params(params)
    end

    test "returns error when prompt is provided without prompt_type" do
      params = %{"content" => "some content", "prompt" => "some prompt"}

      assert {:error, "prompt_type is required when using prompt"} =
               AiAgents.validate_params(params)
    end

    test "returns error when invalid prompt_type is provided" do
      params = %{
        "content" => "some content",
        "prompt" => "some prompt",
        "prompt_type" => "invalid"
      }

      assert {:error, "prompt_type must be one of: suggestion, refinement, extraction"} =
               AiAgents.validate_params(params)
    end

    test "returns ok with valid prompt_id" do
      params = %{"content" => "some content", "prompt_id" => "some-id"}
      assert {:ok, validated} = AiAgents.validate_params(params)
      assert validated.content == "some content"
      assert validated.prompt_id == "some-id"
    end

    test "returns ok with valid prompt and prompt_type" do
      params = %{
        "content" => "some content",
        "prompt" => "some prompt",
        "prompt_type" => "suggestion"
      }

      assert {:ok, validated} = AiAgents.validate_params(params)
      assert validated.content == "some content"
      assert validated.prompt == "some prompt"
      assert validated.prompt_type == :suggestion
    end
  end

  describe "get_prompt_data/1" do
    test "returns error when neither prompt_id nor prompt is provided" do
      params = %{}

      assert {:error, "Either prompt_id or prompt with prompt_type is required"} =
               AiAgents.get_prompt_data(params)
    end

    test "returns inline prompt data when provided" do
      params = %{prompt: "test prompt", prompt_type: :suggestion}
      assert {:ok, prompt_data} = AiAgents.get_prompt_data(params)
      assert prompt_data.prompt == "test prompt"
      assert prompt_data.type == :suggestion
    end
  end

  describe "get_model_or_default/2" do
    setup do
      user = insert(:user_with_organisation)
      %{user: user, org_id: user.current_org_id}
    end

    # create_model/1 auto-defaults the first model in the database, so in
    # the sandbox each test's first created model is the org default
    defp create_model!(user, attrs) do
      defaults = %{
        "name" => "Test Model #{System.unique_integer([:positive])}",
        "description" => "A test model",
        "provider" => "openai",
        "model_name" => "gpt-4o-mini",
        "model_type" => "text",
        "model_version" => "1.0",
        "auth_key" => "test-key",
        "status" => "active",
        "is_local" => false,
        "is_thinking_model" => false,
        "daily_request_limit" => 1000,
        "daily_token_limit" => 100_000,
        "creator_id" => user.id,
        "organisation_id" => user.current_org_id
      }

      {:ok, model} = WraftDoc.Models.create_model(Map.merge(defaults, attrs))
      model
    end

    test "returns explicitly selected active model", %{user: user, org_id: org_id} do
      model = create_model!(user, %{})

      assert {:ok, %{id: id}} = AiAgents.get_model_or_default(%{model_id: model.id}, org_id)
      assert id == model.id
    end

    test "rejects explicitly selected inactive model", %{user: user, org_id: org_id} do
      model = create_model!(user, %{"status" => "inactive"})

      assert {:error, "Model is not active"} =
               AiAgents.get_model_or_default(%{model_id: model.id}, org_id)
    end

    test "returns the active default model", %{user: user, org_id: org_id} do
      model = create_model!(user, %{})
      assert model.is_default

      assert {:ok, %{id: id}} = AiAgents.get_model_or_default(%{model_id: nil}, org_id)
      assert id == model.id
    end

    test "skips an inactive default model", %{user: user, org_id: org_id} do
      model = create_model!(user, %{"status" => "inactive"})
      assert model.is_default

      assert {:error, "No active default model available for this organization"} =
               AiAgents.get_model_or_default(%{model_id: nil}, org_id)
    end
  end

  describe "format_error/1" do
    test "extracts status and provider message from ReqLLM API errors" do
      error =
        ReqLLM.Error.API.Request.exception(
          reason: "Unauthorized",
          status: 401,
          response_body: %{"error" => %{"message" => "Incorrect API key provided"}}
        )

      assert {:error, {401, %{errors: "Incorrect API key provided"}}} =
               AiAgents.format_error(error)
    end

    test "falls back to exception message when there is no provider error body" do
      error = ReqLLM.Error.API.Response.exception(reason: "Malformed JSON", status: 502)

      assert {:error, {502, %{errors: message}}} = AiAgents.format_error(error)
      assert message =~ "Malformed JSON"
    end

    test "returns message without status tuple for non-HTTP exceptions" do
      error = ReqLLM.Error.Validation.Error.exception(reason: "Invalid model spec")

      assert {:error, message} = AiAgents.format_error(error)
      assert message =~ "Invalid model spec"
    end

    test "returns generic error for unrecognized input" do
      assert {:error, "Something went wrong, please try again"} = AiAgents.format_error(:boom)
    end

    test "still decodes legacy inspected-map error strings" do
      message = ~s(request failed %{"error" => %{"code" => 429, "message" => "rate limited"}})

      assert {:error, {429, %{errors: "rate limited"}}} = AiAgents.format_error(message)
    end
  end
end
