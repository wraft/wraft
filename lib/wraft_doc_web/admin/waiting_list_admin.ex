defmodule WraftDocWeb.WaitingListAdmin do
  @moduledoc """
  Admin  Panel for waiting list.
  """
  alias WraftDoc.WaitingLists.WaitingList

  def index(_) do
    [
      first_name: %{name: "First Name", value: fn x -> x.first_name end},
      last_name: %{name: "Last Name", value: fn x -> x.first_name end},
      email: %{name: "Email", value: fn x -> x.email end},
      status: %{name: "Status", value: fn x -> x.status end}
    ]
  end

  def form_fields(_) do
    [
      first_name: %{label: "First Name"},
      last_name: %{label: "Last Name"},
      email: %{label: "Email"},
      status: %{label: "Status"}
    ]
  end

  def after_update(_conn, %WaitingList{status: :approved, email: email} = waiting_list) do
    FunWithFlags.enable(:waiting_list_registration_control, for_actor: %{email: email})
    FunWithFlags.enable(:waiting_list_organisation_create_control, for_actor: %{email: email})
    {:ok, waiting_list}
  end

  def after_update(_conn, waiting_list), do: {:ok, waiting_list}
end
