defmodule WraftDocWeb.AdminNext.WaitingListLive do
  @moduledoc """
  Backpex admin for `WraftDoc.WaitingLists.WaitingList`.

  Mirrors `WraftDocWeb.WaitingListAdmin` (Kaffy):
  - Index: first_name, last_name, email, status (filter), created_at, updated_at.
  - Form: first_name, last_name, email, status.
  - `modified_by_id` is auto-stamped from the current admin on update.
  - Approval workflow: when status flips to `:approved`, run
    `register_account_and_enqueue_email/2` + fire the matching
    AdminEventTrigger events. Mirrors the original Kaffy `after_update/2`
    branch.
  - All lifecycle hooks fire AdminEventTrigger for created/updated/deleted.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.WaitingLists.WaitingList,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.create_changeset/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "People requesting early access. Approve to register an account and send a set-password email."

  import Ecto.Query

  alias WraftDoc.Account
  alias WraftDoc.AdminWebhooks.AdminEventTrigger
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Repo
  alias WraftDoc.WaitingLists.WaitingList
  alias WraftDoc.Workers.EmailWorker
  require Logger

  @impl Backpex.LiveResource
  def singular_name, do: "Waiting List Entry"

  @impl Backpex.LiveResource
  def plural_name, do: "Waiting List"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      first_name: %{module: Backpex.Fields.Text, label: "First Name", searchable: true},
      last_name: %{module: Backpex.Fields.Text, label: "Last Name", searchable: true},
      email: %{module: Backpex.Fields.Text, label: "Email", searchable: true, orderable: true},
      status: %{
        module: Backpex.Fields.Select,
        label: "Status",
        options: [{"Approved", :approved}, {"Rejected", :rejected}, {"Pending", :pending}],
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
        label: "Approved/Updated At",
        except: [:new, :edit],
        orderable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def filters do
    [
      status: %{module: __MODULE__.StatusFilter, label: "Status"}
    ]
  end

  @impl Backpex.LiveResource
  def on_item_created(socket, item) do
    AdminEventTrigger.trigger_waiting_list_created(item, actor(socket))
    socket
  end

  @impl Backpex.LiveResource
  def on_item_updated(socket, %WaitingList{status: :approved} = item) do
    case register_account_and_enqueue_email(item) do
      :ok ->
        AdminEventTrigger.trigger_waiting_list_updated(item, actor(socket))
        AdminEventTrigger.trigger_waiting_list_approved(item, actor(socket))
        Phoenix.LiveView.put_flash(socket, :info, "Approved #{item.email} and queued password email.")

      {:error, reason} ->
        AdminEventTrigger.trigger_waiting_list_updated(item, actor(socket))
        Logger.error("WaitingList approval side-effects failed for #{item.email}: #{inspect(reason)}")

        Phoenix.LiveView.put_flash(
          socket,
          :warning,
          "Status updated, but account/email step failed: #{format_reason(reason)}"
        )
    end
  end

  @impl Backpex.LiveResource
  def on_item_updated(socket, item) do
    AdminEventTrigger.trigger_waiting_list_updated(item, actor(socket))
    socket
  end

  @impl Backpex.LiveResource
  def on_item_deleted(socket, item) do
    AdminEventTrigger.trigger_waiting_list_deleted(item, actor(socket))
    socket
  end

  def create_changeset(waiting_list, attrs, _metadata) do
    WaitingList.changeset(waiting_list, attrs)
  end

  def update_changeset(waiting_list, attrs, metadata) do
    admin_id =
      case Keyword.get(metadata, :assigns, %{})[:current_admin] do
        %{id: id} -> id
        _ -> nil
      end

    attrs =
      case admin_id do
        nil -> attrs
        id -> Map.put(attrs, "modified_by_id", id)
      end

    WaitingList.changeset(waiting_list, attrs)
  end

  defp actor(socket) do
    case socket.assigns[:current_admin] do
      %{id: id, email: email} -> %{id: id, email: email}
      _ -> nil
    end
  end

  defp register_account_and_enqueue_email(%WaitingList{
         email: email,
         first_name: first_name,
         last_name: last_name
       } = waiting_list) do
    FunWithFlags.enable(:waiting_list_registration_control, for_actor: %{email: email})
    FunWithFlags.enable(:waiting_list_organisation_create_control, for_actor: %{email: email})

    with {:ok, %{user: user}} <- create_account(waiting_list),
         %AuthToken{} = token <- AuthTokens.create_set_password_token(user) do
      %{name: "#{first_name} #{last_name}", email: email, token: token.value}
      |> EmailWorker.new(queue: "mailer", tags: ["waiting_list_acceptance"])
      |> Oban.insert()

      :ok
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_account(%WaitingList{email: email, first_name: first_name, last_name: last_name}) do
    case Repo.get_by(WraftDoc.Account.User, email: email) do
      nil ->
        Account.registration(%{
          "name" => "#{first_name} #{last_name}",
          "email" => email,
          "password" => generate_valid_password()
        })

      _user ->
        {:error, "user already exists"}
    end
  end

  defp generate_valid_password do
    lowercase = Enum.take_random(?a..?z, 3)
    uppercase = Enum.take_random(?A..?Z, 3)
    numbers = Enum.take_random(?0..?9, 3)
    special_chars = Enum.take_random([?!, ?@, ?#, ?$, ?%, ?&, ?*], 3)

    (lowercase ++ uppercase ++ numbers ++ special_chars)
    |> Enum.shuffle()
    |> List.to_string()
  end

  defp format_reason(%Ecto.Changeset{} = changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {msg, _opts}} ->
      "#{Phoenix.Naming.humanize(field)} #{msg}"
    end)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defmodule StatusFilter do
    @moduledoc false
    use Backpex.Filters.Boolean

    @impl Backpex.Filter
    def label, do: "Status"

    @impl Backpex.Filters.Boolean
    def options(_assigns) do
      [
        %{label: "Pending", key: "pending", predicate: dynamic([w], w.status == :pending)},
        %{label: "Approved", key: "approved", predicate: dynamic([w], w.status == :approved)},
        %{label: "Rejected", key: "rejected", predicate: dynamic([w], w.status == :rejected)}
      ]
    end
  end
end
