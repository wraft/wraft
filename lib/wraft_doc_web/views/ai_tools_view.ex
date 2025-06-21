defmodule WraftDocWeb.Api.V1.AiToolView do
  use WraftDocWeb, :view

  alias WraftDoc.AiAgents.ResponseModel.Extraction
  alias WraftDoc.AiAgents.ResponseModel.Suggestions

  def render("ai_tool_result.json", %{result: %Extraction{} = result}) do
    %{
      entities: %{
        people: result.entities.people,
        companies: result.entities.companies,
        government_bodies: result.entities.government_bodies,
        courts: result.entities.courts
      },
      dates:
        Enum.map(result.dates, fn date ->
          %{
            date: date.date,
            description: date.description
          }
        end),
      important_clauses:
        Enum.map(result.important_clauses, fn clause ->
          %{
            clause_title: clause.clause_title,
            summary: clause.summary
          }
        end),
      financial_details: %{
        contract_value: %{
          amount: result.financial_details.contract_value.amount,
          currency: result.financial_details.contract_value.currency
        },
        expiry_date: result.financial_details.expiry_date,
        payment_schedule:
          Enum.map(result.financial_details.payment_schedule, fn payment ->
            %{
              amount: payment.amount,
              currency: payment.currency,
              due_date: payment.due_date,
              remarks: payment.remarks
            }
          end)
      }
    }
  end

  def render("ai_tool_result.json", %{result: %Suggestions{} = result}) do
    %{
      suggestions:
        Enum.map(result.suggestions, fn suggestion ->
          %{
            title: suggestion.title,
            description: suggestion.description,
            priority: suggestion.priority,
            text_to_replace: suggestion.text_to_replace,
            text_replacement: suggestion.text_replacement,
            reason: suggestion.reason
          }
        end)
    }
  end

  def render("ai_tool_result.json", %{result: result}), do: %{result: result.refined_content}
end
