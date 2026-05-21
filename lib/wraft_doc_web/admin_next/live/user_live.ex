defmodule WraftDocWeb.AdminNext.UserLive do
  @moduledoc """
  Backpex admin for `WraftDoc.Account.User`.

  Mirrors `WraftDocWeb.UserAdmin` (Kaffy):
  - Index columns: Name, Email, Email Verified (filter), Guest (filter),
    Signed In At, Created At, Updated At — ordered by inserted_at desc.
  - Form: Name, Email (uses User.update_changeset which only persists :name —
    matching Kaffy's existing quirk).
  - Item actions: Resend Email Verification, Resend Set Password, custom
    Delete that also cleans up the user's personal organisation first.
  - Lifecycle hooks: AdminEventTrigger.trigger_user_{created,updated,deleted}/2
    fired from on_item_*/2 with the current admin as actor.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Account.User,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.create_changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Manage users and their roles across organisations."

  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.AdminWebhooks.AdminEventTrigger

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

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
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        orderable: true
      },
      email_verify: %{
        module: Backpex.Fields.Boolean,
        label: "Email Verified",
        except: [:new, :edit],
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            @value && "bg-success/10 text-success",
            !@value && "bg-warning/10 text-warning"
          ]}>
            {if @value, do: "Verified", else: "Pending"}
          </span>
          """
        end
      },
      is_guest: %{
        module: Backpex.Fields.Boolean,
        label: "Guest",
        except: [:new, :edit],
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            @value && "bg-warning/10 text-warning",
            !@value && "bg-success/10 text-success"
          ]}>
            {if @value, do: "Guest", else: "User"}
          </span>
          """
        end
      },
      signed_in_at: %{
        module: Backpex.Fields.DateTime,
        label: "Signed In At",
        except: [:new, :edit],
        orderable: true
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

  @impl Backpex.LiveResource
  def filters do
    [
      email_verify: %{
        module: __MODULE__.EmailVerifyFilter,
        label: "Email Verified"
      },
      is_guest: %{
        module: __MODULE__.GuestFilter,
        label: "Guest"
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    # Replace the default delete with our cascading delete; keep show/edit.
    actions = Keyword.delete(default_actions, :delete)

    actions ++
      [
        resend_verification: %{module: __MODULE__.ResendEmailVerification},
        resend_set_password: %{module: __MODULE__.ResendSetPassword},
        delete: %{module: __MODULE__.CascadingDelete}
      ]
  end

  @impl Backpex.LiveResource
  def on_item_created(socket, item) do
    AdminEventTrigger.trigger_user_created(item, actor(socket))
    socket
  end

  @impl Backpex.LiveResource
  def on_item_updated(socket, item) do
    AdminEventTrigger.trigger_user_updated(item, actor(socket))
    socket
  end

  @impl Backpex.LiveResource
  def on_item_deleted(socket, item) do
    AdminEventTrigger.trigger_user_deleted(item, actor(socket))
    socket
  end

  def item_query(query, _live_action, _assigns) do
    from(q in query, preload: [:roles])
  end

  def create_changeset(user, attrs, _metadata) do
    User.create_changeset(user, attrs)
  end

  def update_changeset(user, attrs, _metadata) do
    User.update_changeset(user, attrs)
  end

  defp actor(socket) do
    case socket.assigns[:current_admin] do
      %{id: id, email: email} -> %{id: id, email: email}
      _ -> nil
    end
  end

  # --- Filters ---

  defmodule EmailVerifyFilter do
    @moduledoc false
    use Backpex.Filters.Boolean

    @impl Backpex.Filter
    def label, do: "Email Verified"

    @impl Backpex.Filters.Boolean
    def options(_assigns) do
      [
        %{label: "Verified", key: "verified", predicate: dynamic([u], u.email_verify == true)},
        %{
          label: "Not Verified",
          key: "not_verified",
          predicate: dynamic([u], u.email_verify == false)
        }
      ]
    end
  end

  defmodule GuestFilter do
    @moduledoc false
    use Backpex.Filters.Boolean

    @impl Backpex.Filter
    def label, do: "Guest"

    @impl Backpex.Filters.Boolean
    def options(_assigns) do
      [
        %{label: "Guest", key: "guest", predicate: dynamic([u], u.is_guest == true)},
        %{label: "User", key: "user", predicate: dynamic([u], u.is_guest == false)}
      ]
    end
  end

  # --- Item actions ---

  defmodule ResendEmailVerification do
    @moduledoc false
    use Backpex.ItemAction

    alias WraftDoc.AuthTokens

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-envelope" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Resend Email Verification"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      Enum.each(items, fn user ->
        AuthTokens.create_token_and_send_email(user.email)
      end)

      {:ok, Phoenix.LiveView.put_flash(socket, :info, "Email verification sent.")}
    end
  end

  defmodule ResendSetPassword do
    @moduledoc false
    use Backpex.ItemAction

    alias WraftDoc.AuthTokens
    alias WraftDoc.Workers.EmailWorker

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-key" class="size-5" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Resend Set Password"

    @impl Backpex.ItemAction
    def handle(socket, items, _params) do
      Enum.each(items, fn user ->
        token = AuthTokens.create_set_password_token(user)

        %{name: user.name, email: user.email, token: token.value}
        |> EmailWorker.new(queue: "mailer", tags: ["waiting_list_acceptance"])
        |> Oban.insert()
      end)

      {:ok, Phoenix.LiveView.put_flash(socket, :info, "Set-password email queued.")}
    end
  end

  defmodule CascadingDelete do
    @moduledoc """
    Deletes the user and their personal organisation in one step, matching
    the original Kaffy admin's delete cascade. Fires AdminEventTrigger.trigger_user_deleted
    via the parent LiveResource's on_item_deleted hook (Backpex calls it after).
    """
    use Backpex.ItemAction

    alias WraftDoc.Account.User, as: UserSchema
    alias WraftDoc.Enterprise
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
    def label(_assigns, _item), do: "Delete"

    @impl Backpex.ItemAction
    def confirm(assigns) do
      count = Enum.count(assigns.selected_items)

      if count > 1 do
        "Delete #{count} users (and each user's personal organisation)?"
      else
        "Delete this user and their personal organisation?"
      end
    end

    @impl Backpex.ItemAction
    def confirm_label(_assigns), do: "Delete"

    @impl Backpex.ItemAction
    def cancel_label(_assigns), do: "Cancel"

    @impl Backpex.ItemAction
    def handle(socket, items, _data) do
      deleted =
        Enum.flat_map(items, fn %UserSchema{} = user ->
          case delete_user_and_personal_org(user) do
            {:ok, deleted_user} ->
              [deleted_user]

            {:error, reason} ->
              Logger.error("UserLive cascading delete failed for #{user.id}: #{inspect(reason)}")
              []
          end
        end)

      Enum.each(deleted, fn deleted_user ->
        socket.assigns.live_resource.on_item_deleted(socket, deleted_user)
      end)

      socket =
        socket
        |> Phoenix.LiveView.clear_flash()
        |> Phoenix.LiveView.put_flash(:info, "Deleted #{length(deleted)} user(s).")

      {:ok, socket}
    end

    defp delete_user_and_personal_org(%UserSchema{} = user) do
      case Enterprise.get_personal_organisation_and_role(user) do
        %{user: user, organisation: personal_org} when not is_nil(personal_org) ->
          with {:ok, _} <- Repo.delete(personal_org) do
            Repo.delete(user)
          end

        _ ->
          Repo.delete(user)
      end
    rescue
      e -> {:error, e}
    end
  end
end
