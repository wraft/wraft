defmodule WraftDoc.AiAgents.ResponseModel.Extraction do
  @moduledoc """
  Schema for extracting information from a document.
  """

  use Ecto.Schema

  @primary_key false
  embedded_schema do
    embeds_one :entities, EntitiesSchema do
      field(:people, {:array, :string})
      field(:companies, {:array, :string})
      field(:government_bodies, {:array, :string})
      field(:courts, {:array, :string})
    end

    embeds_many :dates, DateEntrySchema do
      field(:date, :string)
      field(:description, :string)
    end

    embeds_many :important_clauses, ClauseSchema do
      field(:clause_title, :string)
      field(:summary, :string)
    end

    embeds_one :financial_details, FinancialDetailsSchema do
      embeds_one :contract_value, ContractValueSchema do
        field(:amount, :string)
        field(:currency, :string)
      end

      field(:expiry_date, :string)

      embeds_many :payment_schedule, PaymentScheduleSchema do
        field(:amount, :string)
        field(:currency, :string)
        field(:due_date, :string)
        field(:remarks, :string)
      end
    end
  end

  @doc """
  JSON Schema describing the expected LLM output for this model.
  """
  @spec llm_schema() :: map()
  def llm_schema do
    string = %{"type" => "string"}
    string_array = %{"type" => "array", "items" => string}

    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["entities", "dates", "important_clauses", "financial_details"],
      "properties" => %{
        "entities" => %{
          "type" => "object",
          "additionalProperties" => false,
          "required" => ["people", "companies", "government_bodies", "courts"],
          "properties" => %{
            "people" => string_array,
            "companies" => string_array,
            "government_bodies" => string_array,
            "courts" => string_array
          }
        },
        "dates" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => ["date", "description"],
            "properties" => %{"date" => string, "description" => string}
          }
        },
        "important_clauses" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => ["clause_title", "summary"],
            "properties" => %{"clause_title" => string, "summary" => string}
          }
        },
        "financial_details" => %{
          "type" => "object",
          "additionalProperties" => false,
          "required" => ["contract_value", "expiry_date", "payment_schedule"],
          "properties" => %{
            "contract_value" => %{
              "type" => "object",
              "additionalProperties" => false,
              "required" => ["amount", "currency"],
              "properties" => %{"amount" => string, "currency" => string}
            },
            "expiry_date" => string,
            "payment_schedule" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "additionalProperties" => false,
                "required" => ["amount", "currency", "due_date", "remarks"],
                "properties" => %{
                  "amount" => string,
                  "currency" => string,
                  "due_date" => string,
                  "remarks" => string
                }
              }
            }
          }
        }
      }
    }
  end
end
