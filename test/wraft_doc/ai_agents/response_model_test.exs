defmodule WraftDoc.AiAgents.ResponseModelTest do
  use ExUnit.Case, async: true

  alias WraftDoc.AiAgents.ResponseModel.Extraction
  alias WraftDoc.AiAgents.ResponseModel.Refinement
  alias WraftDoc.AiAgents.ResponseModel.Suggestions
  alias WraftDocWeb.Api.V1.AIToolView

  describe "Extraction" do
    test "loads LLM object output into structs and renders in view" do
      object = %{
        "entities" => %{
          "people" => ["Jane Doe"],
          "companies" => ["Acme Corp"],
          "government_bodies" => [],
          "courts" => []
        },
        "dates" => [%{"date" => "2026-01-01", "description" => "Effective date"}],
        "important_clauses" => [
          %{"clause_title" => "Termination", "summary" => "30 days notice"}
        ],
        "financial_details" => %{
          "contract_value" => %{"amount" => "1000", "currency" => "USD"},
          "expiry_date" => "2027-01-01",
          "payment_schedule" => [
            %{
              "amount" => "500",
              "currency" => "USD",
              "due_date" => "2026-06-01",
              "remarks" => "First installment"
            }
          ]
        }
      }

      result = Ecto.embedded_load(Extraction, object, :json)

      assert %Extraction{} = result
      assert result.entities.people == ["Jane Doe"]
      assert [%{date: "2026-01-01"}] = result.dates
      assert result.financial_details.contract_value.currency == "USD"

      rendered = AIToolView.render("ai_tool_result.json", %{result: result})
      assert rendered.entities.people == ["Jane Doe"]
      assert [%{amount: "500"}] = rendered.financial_details.payment_schedule
    end

    test "llm_schema requires all top-level keys" do
      schema = Extraction.llm_schema()

      assert schema["required"] == [
               "entities",
               "dates",
               "important_clauses",
               "financial_details"
             ]

      assert schema["additionalProperties"] == false
    end
  end

  describe "Suggestions" do
    test "loads LLM object output, casts priority enum, and renders in view" do
      object = %{
        "suggestions" => [
          %{
            "title" => "Clarify clause",
            "description" => "Ambiguous wording",
            "priority" => "high",
            "text_to_replace" => "old text",
            "text_replacement" => "new text",
            "reason" => "Reduces ambiguity"
          }
        ]
      }

      result = Ecto.embedded_load(Suggestions, object, :json)

      assert %Suggestions{} = result
      assert [%{priority: :high, title: "Clarify clause"}] = result.suggestions

      rendered = AIToolView.render("ai_tool_result.json", %{result: result})
      assert [%{priority: :high}] = rendered.suggestions
    end

    test "llm_schema constrains priority to enum values" do
      schema = Suggestions.llm_schema()

      priority =
        schema["properties"]["suggestions"]["items"]["properties"]["priority"]

      assert priority["enum"] == ["high", "medium", "low"]
    end
  end

  describe "Refinement" do
    test "loads LLM object output and renders in view" do
      result = Ecto.embedded_load(Refinement, %{"refined_content" => "Better text"}, :json)

      assert %Refinement{refined_content: "Better text"} = result
      assert %{result: "Better text"} = AIToolView.render("ai_tool_result.json", %{result: result})
    end
  end
end
