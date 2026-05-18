defmodule WraftDoc.AdminWebhooks.AdminWebhook do
  @moduledoc """
  Schema for system-wide admin webhooks. Triggered only by changes performed
  through the Kaffy admin panel mounted at `/admin`.
  """
  use WraftDoc.Schema

  @admin_webhook_events [
    "admin.user.created",
    "admin.user.updated",
    "admin.user.deleted",
    "admin.organisation.created",
    "admin.organisation.updated",
    "admin.organisation.deleted",
    "admin.waiting_list.created",
    "admin.waiting_list.updated",
    "admin.waiting_list.deleted",
    "admin.waiting_list.approved",
    "admin.test"
  ]

  @fields ~w(name url secret events is_active headers retry_count timeout_seconds
            last_triggered_at last_response_status failure_count creator_id)a

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

  schema "admin_webhooks" do
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

    belongs_to(:creator, WraftDoc.InternalUsers.InternalUser)

    timestamps()
  end

  def changeset(admin_webhook, attrs \\ %{}) do
    admin_webhook
    |> cast(attrs, @fields)
    |> validate_required([:name, :url, :events])
    |> validate_admin_webhook_events()
    |> validate_url()
    |> validate_positive_integer(:retry_count)
    |> validate_positive_integer(:timeout_seconds)
    |> unique_constraint(:name,
      name: :admin_webhooks_name_index,
      message: "admin webhook name already exists"
    )
    |> foreign_key_constraint(:creator_id, message: "Please enter a valid internal user")
  end

  def update_changeset(admin_webhook, attrs \\ %{}) do
    admin_webhook
    |> cast(attrs, @fields -- [:creator_id])
    |> validate_required([:name, :url, :events])
    |> validate_admin_webhook_events()
    |> validate_url()
    |> validate_positive_integer(:retry_count)
    |> validate_positive_integer(:timeout_seconds)
    |> unique_constraint(:name,
      name: :admin_webhooks_name_index,
      message: "admin webhook name already exists"
    )
  end

  def trigger_changeset(admin_webhook, attrs \\ %{}) do
    cast(admin_webhook, attrs, [:last_triggered_at, :last_response_status, :failure_count])
  end

  def admin_webhook_events, do: @admin_webhook_events

  defp validate_admin_webhook_events(changeset) do
    case get_field(changeset, :events) do
      nil ->
        changeset

      events ->
        invalid_events = events -- @admin_webhook_events

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
