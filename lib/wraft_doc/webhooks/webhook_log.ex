defmodule WraftDoc.Webhooks.WebhookLog do
  @moduledoc """
  Schema for tracking webhook execution logs.
  """
  use WraftDoc.Schema

  @fields ~w(event url http_method request_headers request_body response_status
            response_headers response_body execution_time_ms success error_message
            attempt_number triggered_at webhook_id organisation_id)a

  @derive {Jason.Encoder,
           only: [
             :id,
             :event,
             :url,
             :http_method,
             :response_status,
             :execution_time_ms,
             :success,
             :error_message,
             :attempt_number,
             :triggered_at,
             :inserted_at
           ]}

  schema "webhook_logs" do
    field(:event, :string)
    field(:url, :string)
    field(:http_method, :string, default: "POST")
    field(:request_headers, :map, default: %{})
    field(:request_body, :string)
    field(:response_status, :integer)
    field(:response_headers, :map, default: %{})
    field(:response_body, :string)
    field(:execution_time_ms, :integer)
    field(:success, :boolean, default: false)
    field(:error_message, :string)
    field(:attempt_number, :integer, default: 1)
    field(:triggered_at, :utc_datetime)

    belongs_to(:webhook, WraftDoc.Webhooks.Webhook)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(webhook_log, attrs \\ %{}) do
    webhook_log
    |> cast(attrs, @fields)
    |> validate_required([:event, :url, :triggered_at, :webhook_id, :organisation_id])
    |> validate_inclusion(:http_method, ["GET", "POST", "PUT", "PATCH", "DELETE"])
    |> validate_number(:attempt_number, greater_than: 0)
    |> validate_number(:execution_time_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:webhook_id, message: "Please enter a valid webhook")
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end

  @doc """
  Create a changeset for logging a webhook request before execution.
  """
  def request_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :event,
      :url,
      :http_method,
      :request_headers,
      :request_body,
      :attempt_number,
      :triggered_at,
      :webhook_id,
      :organisation_id
    ])
    |> validate_required([:event, :url, :triggered_at, :webhook_id, :organisation_id])
    |> validate_inclusion(:http_method, ["GET", "POST", "PUT", "PATCH", "DELETE"])
  end

  @doc """
  Create a changeset for updating a webhook log with response details.
  """
  def response_changeset(webhook_log, attrs) do
    cast(webhook_log, attrs, [
      :response_status,
      :response_headers,
      :response_body,
      :execution_time_ms,
      :success,
      :error_message
    ])
  end
end
