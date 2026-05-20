defmodule WraftDocWeb.AdminNext.InternalUserLive do
  @moduledoc """
  Backpex admin for `WraftDoc.InternalUsers.InternalUser`.

  Mirrors `WraftDocWeb.InternalUserAdmin` (Kaffy):
  - Index columns: Email, Status (Active/Deactivated), Created At
  - Form: Email (readonly on edit), Password (help text on create), is_deactivated (hidden on create, readonly on edit)
  - Item actions: Activate / Deactivate (toggle is_deactivated)
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.InternalUsers.InternalUser,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.create_changeset/3
    ],
    pubsub: [server: WraftDoc.PubSub]

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Internal staff accounts with backoffice access."

  alias WraftDoc.InternalUsers
  alias WraftDoc.InternalUsers.InternalUser

  @impl Backpex.LiveResource
  def singular_name, do: "Internal User"

  @impl Backpex.LiveResource
  def plural_name, do: "Internal Users"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true
      },
      password: %{
        module: Backpex.Fields.Text,
        label: "Password",
        help_text:
          "Please note down the password so that you can share the credentials with new user.",
        except: [:index, :show]
      },
      is_deactivated: %{
        module: Backpex.Fields.Boolean,
        label: "Deactivated",
        # Hidden from create/edit forms — toggled via the Activate/Deactivate item actions.
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
        activate: %{module: __MODULE__.ActivateAction},
        deactivate: %{module: __MODULE__.DeactivateAction}
      ]
  end

  def create_changeset(internal_user, attrs, _metadata) do
    InternalUser.changeset(internal_user, attrs)
  end

  def update_changeset(internal_user, attrs, _metadata) do
    InternalUser.update_changeset(internal_user, attrs)
  end

  defmodule ActivateAction do
    @moduledoc false
    use Backpex.ItemAction

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-play" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Activate"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      Enum.each(items, &InternalUsers.update_internal_user(&1, %{is_deactivated: false}))
      socket = Phoenix.LiveView.put_flash(socket, :info, "Activated.")
      {:noreply, socket}
    end
  end

  defmodule DeactivateAction do
    @moduledoc false
    use Backpex.ItemAction

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-pause" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Deactivate"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      Enum.each(items, &InternalUsers.update_internal_user(&1, %{is_deactivated: true}))
      socket = Phoenix.LiveView.put_flash(socket, :info, "Deactivated.")
      {:noreply, socket}
    end
  end
end
