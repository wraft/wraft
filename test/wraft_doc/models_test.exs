defmodule WraftDoc.ModelsTest do
  @moduledoc """
  Org-scoping and system-prompt guard behaviour for the Models context.
  """
  use WraftDoc.DataCase

  alias WraftDoc.Models
  alias WraftDoc.Models.Prompt

  defp valid_prompt_attrs(org, user) do
    %{
      "title" => "Org Prompt",
      "prompt" => "Summarise the document",
      "status" => "active",
      "type" => "suggestion",
      "creator_id" => user.id,
      "organisation_id" => org.id
    }
  end

  describe "prompt org-scoping and system-prompt guards" do
    setup do
      org_a = insert(:organisation)
      org_b = insert(:organisation)
      user_a = insert(:user)
      {:ok, prompt} = Models.create_prompt(valid_prompt_attrs(org_a, user_a))

      # System prompts are seeded with nil organisation_id + nil creator_id
      # (priv/repo/migrations/20250704045829_seed_prompts.exs) and bypass the
      # changeset's validate_required, so insert the struct directly here.
      system_prompt =
        Repo.insert!(%Prompt{
          title: "Suggestor",
          prompt: "You are a system prompt",
          status: "active",
          type: :suggestion,
          organisation_id: nil,
          creator_id: nil
        })

      %{org_a: org_a, org_b: org_b, prompt: prompt, system_prompt: system_prompt}
    end

    test "get_prompt/2 returns an org's own prompt", %{prompt: prompt, org_a: org_a} do
      assert %Prompt{id: id} = Models.get_prompt(prompt.id, org_a.id)
      assert id == prompt.id
    end

    test "get_prompt/2 does not return another org's owned prompt (no cross-tenant read)",
         %{prompt: prompt, org_b: org_b} do
      assert is_nil(Models.get_prompt(prompt.id, org_b.id))
    end

    test "get_prompt/2 returns a shared system prompt for any org",
         %{system_prompt: system_prompt, org_b: org_b} do
      assert %Prompt{id: id} = Models.get_prompt(system_prompt.id, org_b.id)
      assert id == system_prompt.id
    end

    test "update_prompt/2 refuses to modify a shared system prompt (no cross-tenant hijack)",
         %{system_prompt: system_prompt} do
      assert {:error, "System prompt cannot be modified"} =
               Models.update_prompt(system_prompt, %{"organisation_id" => Ecto.UUID.generate()})

      # The system prompt is untouched: still nil-org, so it stays visible to every tenant.
      assert %Prompt{organisation_id: nil, creator_id: nil} = Repo.get(Prompt, system_prompt.id)
    end

    test "update_prompt/2 updates an org-owned prompt", %{prompt: prompt} do
      assert {:ok, %Prompt{title: "Renamed"}} =
               Models.update_prompt(prompt, %{"title" => "Renamed"})
    end

    test "delete_prompt/1 refuses to delete a shared system prompt",
         %{system_prompt: system_prompt} do
      assert {:error, "System prompt cannot be deleted"} = Models.delete_prompt(system_prompt)
    end
  end
end
