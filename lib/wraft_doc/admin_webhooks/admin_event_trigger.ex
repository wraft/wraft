defmodule WraftDoc.AdminWebhooks.AdminEventTrigger do
  @moduledoc """
  Builds payloads and dispatches admin webhook events for the three resources
  managed via the Kaffy admin panel: User, Organisation, and WaitingList.
  """
  alias WraftDoc.Account.User
  alias WraftDoc.AdminWebhooks
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.WaitingLists.WaitingList

  @type actor :: %{required(:id) => binary(), required(:email) => binary()} | nil

  # === User events ===

  @spec trigger_user_created(User.t(), actor) :: :ok
  def trigger_user_created(%User{} = user, actor \\ nil),
    do: dispatch("admin.user.created", user_data(user, "created"), actor)

  @spec trigger_user_updated(User.t(), actor) :: :ok
  def trigger_user_updated(%User{} = user, actor \\ nil),
    do: dispatch("admin.user.updated", user_data(user, "updated"), actor)

  @spec trigger_user_deleted(User.t(), actor) :: :ok
  def trigger_user_deleted(%User{} = user, actor \\ nil),
    do: dispatch("admin.user.deleted", user_data(user, "deleted"), actor)

  # === Organisation events ===

  @spec trigger_organisation_created(Organisation.t(), actor) :: :ok
  def trigger_organisation_created(%Organisation{} = org, actor \\ nil),
    do: dispatch("admin.organisation.created", organisation_data(org, "created", false), actor)

  @spec trigger_organisation_updated(Organisation.t(), actor) :: :ok
  def trigger_organisation_updated(%Organisation{} = org, actor \\ nil),
    do: dispatch("admin.organisation.updated", organisation_data(org, "updated", false), actor)

  @doc """
  Soft-delete is the only deletion path through OrganisationAdmin (see
  `WraftDocWeb.OrganisationAdmin.delete/2`), so the payload always reports
  `soft_deleted: true`.
  """
  @spec trigger_organisation_deleted(Organisation.t(), actor) :: :ok
  def trigger_organisation_deleted(%Organisation{} = org, actor \\ nil),
    do: dispatch("admin.organisation.deleted", organisation_data(org, "deleted", true), actor)

  # === WaitingList events ===

  @spec trigger_waiting_list_created(WaitingList.t(), actor) :: :ok
  def trigger_waiting_list_created(%WaitingList{} = wl, actor \\ nil),
    do: dispatch("admin.waiting_list.created", waiting_list_data(wl, "created"), actor)

  @spec trigger_waiting_list_updated(WaitingList.t(), actor) :: :ok
  def trigger_waiting_list_updated(%WaitingList{} = wl, actor \\ nil),
    do: dispatch("admin.waiting_list.updated", waiting_list_data(wl, "updated"), actor)

  @spec trigger_waiting_list_approved(WaitingList.t(), actor) :: :ok
  def trigger_waiting_list_approved(%WaitingList{} = wl, actor \\ nil),
    do: dispatch("admin.waiting_list.approved", waiting_list_data(wl, "approved"), actor)

  @spec trigger_waiting_list_deleted(WaitingList.t(), actor) :: :ok
  def trigger_waiting_list_deleted(%WaitingList{} = wl, actor \\ nil),
    do: dispatch("admin.waiting_list.deleted", waiting_list_data(wl, "deleted"), actor)

  @spec trigger_waiting_list_confirmation_email_sent(WaitingList.t(), actor) :: :ok
  def trigger_waiting_list_confirmation_email_sent(%WaitingList{} = wl, actor \\ nil),
    do:
      dispatch(
        "admin.waiting_list.confirmation_email_sent",
        waiting_list_data(wl, "confirmation_email_sent"),
        actor
      )

  # === Test event ===

  @spec trigger_test(actor) :: :ok
  def trigger_test(actor \\ nil),
    do: dispatch("admin.test", %{message: "This is a test admin webhook event."}, actor)

  # === Internal ===

  defp dispatch(event, data, actor),
    do: AdminWebhooks.trigger_admin_webhooks(event, data, actor)

  defp user_data(%User{} = user, action) do
    %{
      user: %{
        id: user.id,
        name: user.name,
        email: user.email,
        email_verify: user.email_verify,
        is_guest: user.is_guest,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      },
      action: action
    }
  end

  defp organisation_data(%Organisation{} = org, action, soft_deleted?) do
    %{
      organisation: %{
        id: org.id,
        name: org.name,
        legal_name: org.legal_name,
        email: org.email,
        inserted_at: org.inserted_at,
        updated_at: org.updated_at
      },
      action: action,
      soft_deleted: soft_deleted?
    }
  end

  defp waiting_list_data(%WaitingList{} = wl, action) do
    %{
      waiting_list: %{
        id: wl.id,
        first_name: wl.first_name,
        last_name: wl.last_name,
        email: wl.email,
        status: to_string(wl.status),
        inserted_at: wl.inserted_at,
        updated_at: wl.updated_at
      },
      action: action
    }
  end
end
