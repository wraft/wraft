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
end
