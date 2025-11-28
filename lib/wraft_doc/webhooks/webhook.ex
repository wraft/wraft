defmodule WraftDoc.Webhooks.Webhook do
  @moduledoc """
  The webhook schema for organization-wise webhook management.
  """
  use WraftDoc.Schema

  @webhook_events [
    "document.created",
    "document.sent",
    "document.completed",
    "document.cancelled",
    "document.signed",
    "document.rejected",
    "document.state_updated",
    "document.comment_added",
    "document.deleted",
    "document.reminder_sent",
    "pipeline.completed",
    "pipeline.failed",
    "pipeline.partially_completed",
    "test"
  ]

  @fields ~w(name url secret events is_active headers retry_count timeout_seconds
            last_triggered_at last_response_status failure_count organisation_id creator_id)a

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :url,
             :events,
             :is_active,
             :headers,
             :retry_count,
             :timeout_seconds,
             :last_triggered_at,
             :last_response_status,
             :failure_count,
             :inserted_at,
             :updated_at
           ]}

  schema "webhooks" do
    field(:name, :string)
    field(:url, :string)
    field(:secret, :string)
    field(:events, {:array, :string}, default: [])
    field(:is_active, :boolean, default: true)
    field(:headers, :map, default: %{})
    field(:retry_count, :integer, default: 3)
    field(:timeout_seconds, :integer, default: 30)
    field(:last_triggered_at, :utc_datetime)
    field(:last_response_status, :integer)
    field(:failure_count, :integer, default: 0)

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(webhook, attrs \\ %{}) do
    webhook
    |> cast(attrs, @fields)
    |> validate_required([:name, :url, :events, :organisation_id, :creator_id])
    |> validate_webhook_events()
    |> validate_url()
    |> validate_positive_integer(:retry_count)
    |> validate_positive_integer(:timeout_seconds)
    |> unique_constraint(:name,
      name: :webhooks_name_organisation_id_index,
      message: "webhook name already exists in this organisation"
    )
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
    |> foreign_key_constraint(:creator_id, message: "Please enter a valid user")
  end

  def update_changeset(webhook, attrs \\ %{}) do
    webhook
    |> cast(attrs, @fields -- [:organisation_id, :creator_id])
    |> validate_required([:name, :url, :events])
    |> validate_webhook_events()
    |> validate_url()
    |> validate_positive_integer(:retry_count)
    |> validate_positive_integer(:timeout_seconds)
    |> unique_constraint(:name,
      name: :webhooks_name_organisation_id_index,
      message: "webhook name already exists in this organisation"
    )
  end

  def trigger_changeset(webhook, attrs \\ %{}) do
    cast(webhook, attrs, [:last_triggered_at, :last_response_status, :failure_count])
  end

  def webhook_events, do: @webhook_events

  defp validate_webhook_events(changeset) do
    case get_field(changeset, :events) do
      nil ->
        changeset

      events ->
        invalid_events = events -- @webhook_events

        if Enum.empty?(invalid_events) do
          changeset
        else
          add_error(
            changeset,
            :events,
            "contains invalid events: #{Enum.join(invalid_events, ", ")}"
          )
        end
    end
  end

  defp validate_url(changeset) do
    case get_field(changeset, :url) do
      nil ->
        changeset

      url ->
        uri = URI.parse(url)

        if uri.scheme in ["http", "https"] and not is_nil(uri.host) do
          changeset
        else
          add_error(changeset, :url, "must be a valid HTTP or HTTPS URL")
        end
    end
  end

  defp validate_positive_integer(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      value when is_integer(value) and value > 0 -> changeset
      _ -> add_error(changeset, field, "must be a positive integer")
    end
  end
end
