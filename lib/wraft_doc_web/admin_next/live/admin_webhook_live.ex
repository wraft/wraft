defmodule WraftDocWeb.AdminNext.AdminWebhookLive do
  @moduledoc """
  Backpex admin for `WraftDoc.AdminWebhooks.AdminWebhook`.

  Mirrors `WraftDocWeb.AdminWebhookAdmin` (Kaffy):
  - Index: name, url, events, is_active, last_triggered_at, last_response_status,
    failure_count, creator, inserted_at.
  - Form: name, url, secret (password), events (JSON array textarea),
    is_active, headers (JSON object textarea), retry_count, timeout_seconds.
  - `creator_id` is auto-stamped from the current admin on create.
  - JSON parsing for `events` / `headers` on save matches the Kaffy admin's
    normalize_params/1 — empty input → identity value ([], %{}); invalid JSON
    falls through to Ecto, which produces an `is invalid` validation error.
  - Item actions: Send Test Event, Activate, Deactivate.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.AdminWebhooks.AdminWebhook,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.create_changeset/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle:
      "Outbound webhooks fired on admin events. Configure URL, secret, and which events trigger a POST."

  alias WraftDoc.AdminWebhooks.AdminWebhook

  @impl Backpex.LiveResource
  def singular_name, do: "Admin Webhook"

  @impl Backpex.LiveResource
  def plural_name, do: "Admin Webhooks"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    events_help =
      "JSON array. Allowed: " <> Enum.join(AdminWebhook.admin_webhook_events(), ", ")

    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        orderable: true
      },
      url: %{
        module: Backpex.Fields.Text,
        label: "URL",
        help_text: "HTTPS endpoint that will receive signed POSTs"
      },
      secret: %{
        module: Backpex.Fields.Text,
        label: "Signing Secret",
        help_text: "HMAC-SHA256 key for the X-WraftDoc-Admin-Signature header",
        except: [:index, :show]
      },
      events: %{
        module: Backpex.Fields.Textarea,
        label: "Events",
        help_text: events_help,
        render: fn assigns ->
          ~H'<span>{(@value || []) |> Enum.join(", ")}</span>'
        end,
        render_form: fn assigns ->
          ~H"""
          <textarea
            id={Phoenix.HTML.Form.input_id(@form, @name)}
            name={Phoenix.HTML.Form.input_name(@form, @name)}
            class="textarea textarea-bordered w-full font-mono text-xs"
            rows="5"
          ><%= WraftDocWeb.AdminNext.AdminWebhookLive.encode_json_value(@form[@name].value) %></textarea>
          """
        end
      },
      is_active: %{
        module: Backpex.Fields.Boolean,
        label: "Active",
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            @value && "bg-success/10 text-success",
            !@value && "bg-error/10 text-error"
          ]}>
            {if @value, do: "Active", else: "Inactive"}
          </span>
          """
        end
      },
      headers: %{
        module: Backpex.Fields.Textarea,
        label: "Custom Headers",
        help_text: ~s|JSON object. Example: {"X-API-Key": "abc"}|,
        except: [:index],
        render: fn assigns ->
          ~H'<span class="font-mono text-xs">{Jason.encode!(@value || %{})}</span>'
        end,
        render_form: fn assigns ->
          ~H"""
          <textarea
            id={Phoenix.HTML.Form.input_id(@form, @name)}
            name={Phoenix.HTML.Form.input_name(@form, @name)}
            class="textarea textarea-bordered w-full font-mono text-xs"
            rows="3"
          ><%= WraftDocWeb.AdminNext.AdminWebhookLive.encode_json_value(@form[@name].value) %></textarea>
          """
        end
      },
      retry_count: %{module: Backpex.Fields.Number, label: "Retry Count"},
      timeout_seconds: %{module: Backpex.Fields.Number, label: "Timeout (seconds)"},
      last_triggered_at: %{
        module: Backpex.Fields.DateTime,
        label: "Last Triggered",
        except: [:new, :edit]
      },
      last_response_status: %{
        module: Backpex.Fields.Number,
        label: "Last Status",
        except: [:new, :edit]
      },
      failure_count: %{
        module: Backpex.Fields.Number,
        label: "Failures",
        except: [:new, :edit]
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        except: [:new, :edit],
        orderable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    default_actions ++
      [
        send_test_event: %{module: __MODULE__.SendTestEvent},
        activate: %{module: __MODULE__.Activate},
        deactivate: %{module: __MODULE__.Deactivate}
      ]
  end

  def create_changeset(webhook, attrs, metadata) do
    creator_id =
      case Keyword.get(metadata, :assigns, %{})[:current_admin] do
        %{id: id} -> id
        _ -> nil
      end

    attrs =
      attrs
      |> normalize_params()
      |> maybe_put_creator_id(creator_id)

    AdminWebhook.changeset(webhook, attrs)
  end

  def update_changeset(webhook, attrs, _metadata) do
    AdminWebhook.update_changeset(webhook, normalize_params(attrs))
  end

  defp maybe_put_creator_id(attrs, nil), do: attrs
  defp maybe_put_creator_id(attrs, id), do: Map.put_new(attrs, "creator_id", id)

  defp normalize_params(params) do
    params
    |> normalize_json_field("events", &is_list/1)
    |> normalize_json_field("headers", &is_map/1)
  end

  defp normalize_json_field(%{} = params, key, valid_fun) do
    case Map.get(params, key) do
      raw when is_binary(raw) -> Map.put(params, key, parse_json(raw, valid_fun, raw))
      _ -> params
    end
  end

  defp normalize_json_field(params, _key, _valid_fun), do: params

  defp parse_json(raw, valid_fun, fallback) do
    case String.trim(raw) do
      "" -> empty_value(valid_fun)
      trimmed -> decode_and_validate(trimmed, valid_fun, fallback)
    end
  end

  defp decode_and_validate(trimmed, valid_fun, fallback) do
    case Jason.decode(trimmed) do
      {:ok, decoded} -> if valid_fun.(decoded), do: decoded, else: fallback
      {:error, _} -> fallback
    end
  end

  defp empty_value(valid_fun) do
    cond do
      valid_fun.([]) -> []
      valid_fun.(%{}) -> %{}
      true -> nil
    end
  end

  @doc """
  Serializes a list/map back into a JSON-encoded string for textarea display.
  Used by the `events` and `headers` `render_form` fns. Strings pass through
  unchanged so re-renders after a failed submit show the user's raw input.
  """
  def encode_json_value(nil), do: ""
  def encode_json_value(value) when is_binary(value), do: value
  def encode_json_value(value), do: Jason.encode!(value)

  # --- Item actions ---

  defmodule SendTestEvent do
    @moduledoc false
    use Backpex.ItemAction

    alias WraftDoc.AdminWebhooks.AdminEventTrigger

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-paper-airplane" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Send Test Event"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      actor =
        case socket.assigns[:current_admin] do
          %{id: id, email: email} -> %{id: id, email: email}
          _ -> nil
        end

      {sent, skipped} =
        Enum.split_with(items, fn webhook ->
          "admin.test" in (webhook.events || [])
        end)

      if sent != [], do: AdminEventTrigger.trigger_test(actor)

      msg =
        case {length(sent), length(skipped)} do
          {sent_count, 0} ->
            "Test event sent to #{sent_count} webhook(s)."

          {0, _} ->
            "No selected webhook subscribes to admin.test."

          {sent_count, skipped_count} ->
            "Sent to #{sent_count}; #{skipped_count} not subscribed to admin.test."
        end

      {:ok, Phoenix.LiveView.put_flash(socket, :info, msg)}
    end
  end

  defmodule Activate do
    @moduledoc false
    use Backpex.ItemAction

    alias WraftDoc.AdminWebhooks

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-play" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Activate"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      Enum.each(items, &AdminWebhooks.update_admin_webhook(&1, %{"is_active" => true}))
      {:ok, Phoenix.LiveView.put_flash(socket, :info, "Activated #{length(items)} webhook(s).")}
    end
  end

  defmodule Deactivate do
    @moduledoc false
    use Backpex.ItemAction

    alias WraftDoc.AdminWebhooks

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-pause" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Deactivate"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      Enum.each(items, &AdminWebhooks.update_admin_webhook(&1, %{"is_active" => false}))
      {:ok, Phoenix.LiveView.put_flash(socket, :info, "Deactivated #{length(items)} webhook(s).")}
    end
  end
end
