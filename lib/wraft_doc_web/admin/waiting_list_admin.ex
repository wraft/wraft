defmodule WraftDocWeb.WaitingListAdmin do
  @moduledoc """
  Admin  Panel for waiting list.
  """

  alias WraftDoc.Account
  alias WraftDoc.AuthTokens
  alias WraftDoc.Kaffy.CustomDataAdmin
  alias WraftDoc.WaitingLists.WaitingList
  alias WraftDoc.Workers.EmailWorker

  def widgets(_schema, _conn) do
    pending_user_count = CustomDataAdmin.get_pending_user_count()
    chart_data = CustomDataAdmin.get_user_registration_chart_data()

    [
      %{
        icon: "hourglass-start",
        type: "tidbit",
        title: "Waiting User",
        content: pending_user_count,
        order: 1,
        width: 3
      },
      %{
        type: "chart",
        title: "User Registrations Over Last 30 Days",
        order: 8,
        width: 12,
        content: chart_data
      }
    ]
  end

  def index(_) do
    [
      first_name: %{name: "First Name", value: fn x -> x.first_name end},
      last_name: %{name: "Last Name", value: fn x -> x.last_name end},
      email: %{name: "Email", value: fn x -> x.email end},
      status: %{name: "Status", value: fn x -> x.status end},
      inserted_at: %{name: "Created At", value: fn x -> x.inserted_at end},
      updated_at: %{name: "Approved At", value: fn x -> x.updated_at end}
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

  def ordering(_schema) do
    # order by created_at
    [desc: :inserted_at]
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
    {:ok, %{user: user}} = create_account(waiting_list)
    token = create_set_password_token(user)
    # Send email notification
    %{name: "#{first_name} #{last_name}", email: email, token: token.value}
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

  def create_set_password_token(user) do
    token = WraftDoc.create_phx_token("set_password", user.email, max_age: :infinity)
    params = %{value: token, token_type: "set_password"}
    AuthTokens.insert_auth_token!(user, params)
  end
end
