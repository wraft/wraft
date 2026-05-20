defmodule WraftDocWeb.AdminNext.OrganisationLive do
  @moduledoc """
  Backpex admin for `WraftDoc.Enterprise.Organisation`.

  Mirrors `WraftDocWeb.OrganisationAdmin` (Kaffy):
  - Index columns: Name, Email, Created At, Updated At, Soft Deleted indicator.
  - Form: name, legal_name, address (textarea), name_of_ceo, name_of_cto,
    gstin, corporate_id, phone, email.
  - Index query: excludes "Personal" organisations; preloads
    `users_organisations` (for soft-deleted indicator) and `modified_by`.
  - Item action: custom "Soft Delete" replacing the default Delete — sets
    `user_organisations.deleted_at` for the org and stamps
    `organisation.modified_by_id` with the current admin's id (matching the
    Multi pipeline in the Kaffy admin).
  - Lifecycle hooks: AdminEventTrigger.trigger_organisation_*/2 fired from
    `on_item_created/updated/deleted`.

  Known limitations vs. Kaffy:
  - Logo upload (Waffle) is not yet wired into the Backpex form; the column
    remains writable in the database, just not from this UI.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Enterprise.Organisation,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.create_changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Tenants on the platform — excluding personal organisations."

  import Ecto.Query

  alias WraftDoc.AdminWebhooks.AdminEventTrigger
  alias WraftDoc.Enterprise.Organisation

  @impl Backpex.LiveResource
  def singular_name, do: "Organisation"

  @impl Backpex.LiveResource
  def plural_name, do: "Organisations"

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
      legal_name: %{
        module: Backpex.Fields.Text,
        label: "Legal name",
        searchable: true
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        orderable: true
      },
      address: %{
        module: Backpex.Fields.Textarea,
        label: "Address",
        except: [:index]
      },
      name_of_ceo: %{module: Backpex.Fields.Text, label: "Name of CEO", except: [:index]},
      name_of_cto: %{module: Backpex.Fields.Text, label: "Name of CTO", except: [:index]},
      gstin: %{module: Backpex.Fields.Text, label: "GSTIN", except: [:index]},
      corporate_id: %{module: Backpex.Fields.Text, label: "Corporate id", except: [:index]},
      phone: %{module: Backpex.Fields.Text, label: "Phone", except: [:index]},
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

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    actions = Keyword.delete(default_actions, :delete)
    actions ++ [delete: %{module: __MODULE__.SoftDelete}]
  end

  @impl Backpex.LiveResource
  def on_item_created(socket, item) do
    AdminEventTrigger.trigger_organisation_created(item, actor(socket))
    socket
  end

  @impl Backpex.LiveResource
  def on_item_updated(socket, item) do
    AdminEventTrigger.trigger_organisation_updated(item, actor(socket))
    socket
  end

  @impl Backpex.LiveResource
  def on_item_deleted(socket, item) do
    AdminEventTrigger.trigger_organisation_deleted(item, actor(socket))
    socket
  end

  def item_query(query, _live_action, _assigns) do
    from(q in query,
      where: q.name != "Personal",
      preload: [:users_organisations, :modified_by]
    )
  end

  def create_changeset(organisation, attrs, _metadata) do
    Organisation.changeset(organisation, attrs)
  end

  def update_changeset(organisation, attrs, _metadata) do
    Organisation.update_changeset(organisation, attrs)
  end

  defp actor(socket) do
    case socket.assigns[:current_admin] do
      %{id: id, email: email} -> %{id: id, email: email}
      _ -> nil
    end
  end

  # --- Custom soft-delete item action ---

  defmodule SoftDelete do
    @moduledoc """
    Marks the organisation's user_organisations as soft-deleted and stamps the
    organisation's modified_by_id with the current admin. Mirrors the
    `Multi.update_all + Multi.update` flow in the Kaffy admin.
    """
    use Backpex.ItemAction

    alias Ecto.Multi
    alias WraftDoc.Account.UserOrganisation
    alias WraftDoc.Enterprise.Organisation, as: OrgSchema
    alias WraftDoc.Repo
    require Logger

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H"""
      <Backpex.HTML.CoreComponents.icon
        name="hero-trash"
        class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-red-600"
      />
      """
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Soft delete"

    @impl Backpex.ItemAction
    def confirm(assigns) do
      count = Enum.count(assigns.selected_items)

      if count > 1 do
        "Soft-delete #{count} organisations? Their memberships will be marked deleted."
      else
        "Soft-delete this organisation? Memberships will be marked deleted."
      end
    end

    @impl Backpex.ItemAction
    def confirm_label(_assigns), do: "Soft delete"

    @impl Backpex.ItemAction
    def cancel_label(_assigns), do: "Cancel"

    @impl Backpex.ItemAction
    def handle(socket, items, _data) do
      admin_id =
        case socket.assigns[:current_admin] do
          %{id: id} -> id
          _ -> nil
        end

      deleted =
        Enum.flat_map(items, fn %OrgSchema{} = org ->
          case soft_delete(org, admin_id) do
            {:ok, updated} -> [updated]
            {:error, reason} ->
              Logger.error("OrganisationLive soft-delete failed for #{org.id}: #{inspect(reason)}")
              []
          end
        end)

      Enum.each(deleted, fn org ->
        socket.assigns.live_resource.on_item_deleted(socket, org)
      end)

      {:ok,
       socket
       |> Phoenix.LiveView.clear_flash()
       |> Phoenix.LiveView.put_flash(:info, "Soft-deleted #{length(deleted)} organisation(s).")}
    end

    defp soft_delete(%OrgSchema{id: org_id} = org, admin_id) do
      now = DateTime.utc_now()

      Multi.new()
      |> Multi.update_all(
        :soft_delete_user_organisations,
        from(uo in UserOrganisation, where: uo.organisation_id == ^org_id),
        set: [deleted_at: now]
      )
      |> Multi.update(
        :stamp_modified_by,
        OrgSchema.changeset(org, %{modified_by_id: admin_id})
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{stamp_modified_by: updated}} -> {:ok, updated}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end
end
