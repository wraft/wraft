defmodule WraftDocWeb.AdminNext.FieldTypeLive do
  @moduledoc """
  Backpex admin for `WraftDoc.Fields.FieldType`.

  Mirrors `WraftDocWeb.FieldTypeAdmin` (Kaffy):
  - Index columns: Name, Description, Meta (JSON), Disabled, Created At, Updated At
  - Index query: preload :creator
  - Default ordering: `inserted_at asc`
  - Custom changeset: parses the `validations` form field from a JSON string
    into a list of maps before passing it to `FieldType.changeset/2`.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Fields.FieldType,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :asc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Custom field type definitions used in templates and forms."

  import Ecto.Query

  alias WraftDoc.Fields.FieldType

  @impl Backpex.LiveResource
  def singular_name, do: "Field Type"

  @impl Backpex.LiveResource
  def plural_name, do: "Field Types"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        orderable: true
      },
      description: %{
        module: Backpex.Fields.Text,
        label: "Description",
        searchable: true
      },
      meta: %{
        module: Backpex.Fields.Text,
        label: "Meta (JSON)",
        # Read-only on this admin — meta is a Map column edited elsewhere (seeds/API).
        except: [:new, :edit],
        render: fn assigns ->
          ~H"""
          <span class="font-mono text-xs">{Jason.encode!(@value)}</span>
          """
        end
      },
      validations: %{
        module: Backpex.Fields.Text,
        label: "Validations",
        # embeds_many — read-only on this admin; rendered as JSON for visibility.
        except: [:new, :edit],
        render: fn assigns ->
          ~H"""
          <span class="font-mono text-xs">{Jason.encode!(@value)}</span>
          """
        end
      },
      is_disabled: %{
        module: Backpex.Fields.Boolean,
        label: "Status",
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            @value && "bg-error/10 text-error",
            !@value && "bg-success/10 text-success"
          ]}>
            {if @value, do: "Disabled", else: "Enabled"}
          </span>
          """
        end
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        except: [:new, :edit],
        orderable: true
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated At",
        except: [:new, :edit],
        orderable: true
      }
    ]
  end

  def item_query(query, _live_action, _assigns) do
    from(q in query, preload: [:creator])
  end

  def changeset(field_type, attrs, _metadata) do
    FieldType.changeset(field_type, attrs)
  end
end
