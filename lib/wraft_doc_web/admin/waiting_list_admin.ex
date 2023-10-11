defmodule WraftDocWeb.WaitingListAdmin do
  @moduledoc """
  Admin  Panel for waiting list.
  """

  alias WraftDoc.Account
  alias WraftDoc.WaitingLists.WaitingList
  alias WraftDoc.Workers.EmailWorker

  def index(_) do
    [
      first_name: %{name: "First Name", value: fn x -> x.first_name end},
      last_name: %{name: "Last Name", value: fn x -> x.last_name end},
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

  def after_update(
        _conn,
        %WaitingList{
          status: :approved,
          email: email,
          first_name: first_name,
          last_name: last_name
        } = waiting_list
      ) do
    # Flag Enable
    FunWithFlags.enable(:waiting_list_registration_control, for_actor: %{email: email})
    FunWithFlags.enable(:waiting_list_organisation_create_control, for_actor: %{email: email})
    create_account(waiting_list)
    # Send email notification
    %{name: "#{first_name} #{last_name}", email: email}
    |> EmailWorker.new(queue: "mailer", tags: ["waiting_list_acceptance"])
    |> Oban.insert()

    {:ok, waiting_list}
  end

  def after_update(_conn, waiting_list), do: {:ok, waiting_list}

  defp create_account(%WaitingList{email: email, first_name: first_name, last_name: last_name}) do
    random_password = 8 |> :crypto.strong_rand_bytes() |> Base.encode16() |> binary_part(0, 8)

    params = %{
      "name" => "#{first_name} #{last_name}",
      "email" => email,
      "password" => random_password
    }

    Account.registration(params)
  end
end
