defmodule WraftDocWeb.WaitingListAdmin do
  @moduledoc """
  Admin  Panel for waiting list.
  """
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
end
