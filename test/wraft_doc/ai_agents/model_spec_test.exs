defmodule WraftDoc.AiAgents.ModelSpecTest do
  use ExUnit.Case, async: true

  alias WraftDoc.AiAgents.ModelSpec

  describe "build/1" do
    test "maps openai provider without endpoint" do
      assert {:ok, %{provider: :openai, id: "gpt-4o"}} =
               ModelSpec.build(%{provider: "openai", model_name: "gpt-4o", endpoint_url: nil})
    end

    test "maps google provider" do
      assert {:ok, %{provider: :google, id: "gemini-2.0-flash"}} =
               ModelSpec.build(%{
                 provider: "google",
                 model_name: "gemini-2.0-flash",
                 endpoint_url: nil
               })
    end

    test "maps anthropic provider" do
      assert {:ok, %{provider: :anthropic, id: "claude-sonnet-4-20250514"}} =
               ModelSpec.build(%{
                 provider: "anthropic",
                 model_name: "claude-sonnet-4-20250514",
                 endpoint_url: nil
               })
    end

    test "routes llamacpp through openai provider with base_url" do
      assert {:ok,
              %{provider: :openai, id: "llama-3.1-8b", base_url: "http://localhost:8080/v1"}} =
               ModelSpec.build(%{
                 provider: "llamacpp",
                 model_name: "llama-3.1-8b",
                 endpoint_url: "http://localhost:8080/v1"
               })
    end

    test "routes ollama through native ollama provider with base_url" do
      assert {:ok, %{provider: :ollama, id: "llama3", base_url: "http://localhost:11434"}} =
               ModelSpec.build(%{
                 provider: "ollama",
                 model_name: "llama3",
                 endpoint_url: "http://localhost:11434"
               })
    end

    test "returns error when llamacpp has no endpoint_url" do
      assert {:error, "endpoint_url is required for provider: llamacpp"} =
               ModelSpec.build(%{provider: "llamacpp", model_name: "llama", endpoint_url: nil})
    end

    test "passes endpoint_url as base_url for hosted providers" do
      assert {:ok, %{provider: :openai, id: "gpt-4o", base_url: "https://proxy.example.com/v1"}} =
               ModelSpec.build(%{
                 provider: "openai",
                 model_name: "gpt-4o",
                 endpoint_url: "https://proxy.example.com/v1"
               })
    end

    test "maps hosted providers groq, mistral and openrouter" do
      for {db_provider, expected} <- [
            {"groq", :groq},
            {"mistral", :mistral},
            {"openrouter", :openrouter}
          ] do
        assert {:ok, %{provider: ^expected, id: "m"}} =
                 ModelSpec.build(%{provider: db_provider, model_name: "m", endpoint_url: nil})
      end
    end

    test "returns error for unsupported provider" do
      assert {:error, "Unsupported AI provider: bedrock"} =
               ModelSpec.build(%{provider: "bedrock", model_name: "x", endpoint_url: nil})
    end
  end

  describe "supported_providers/0" do
    test "lists every provider build/1 accepts" do
      providers = ModelSpec.supported_providers()

      assert "openai" in providers
      assert "llamacpp" in providers

      for provider <- providers do
        endpoint = if provider in ["llamacpp", "ollama"], do: "http://localhost:1", else: nil

        assert {:ok, _spec} =
                 ModelSpec.build(%{provider: provider, model_name: "m", endpoint_url: endpoint})
      end
    end
  end

  describe "provider_options/0" do
    test "returns value, label and requires_endpoint for each provider" do
      options = ModelSpec.provider_options()

      assert length(options) == length(ModelSpec.supported_providers())

      assert %{value: "llamacpp", label: "llama.cpp", requires_endpoint: true} in options
      assert %{value: "openai", label: "OpenAI", requires_endpoint: false} in options
    end
  end
end
