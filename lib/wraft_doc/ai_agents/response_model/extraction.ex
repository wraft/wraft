defmodule WraftDoc.AiAgents.ResponseModel.Extraction do
  @moduledoc """
  Schema for extracting information from a document.
  """

  use Ecto.Schema
  use Instructor

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
end
