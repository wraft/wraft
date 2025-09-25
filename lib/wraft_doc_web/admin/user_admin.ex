defmodule WraftDocWeb.UserAdmin do
  @moduledoc """
  Admin panel for user
  """
  import Ecto.Query
  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.Enterprise
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Router.Helpers, as: Routes

  def widgets(_schema, _conn) do
    query = from(u in User, select: count(u.id))
    user_count = Repo.one(query)

    [
      %{
        icon: "users",
        type: "tidbit",
        title: "Registered Users",
        content: user_count,
        order: 2,
        width: 3
      }
    ]
  end

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      email: %{name: "Email", value: fn x -> x.email end},
      email_verify: %{name: "Email Verified", value: fn x -> x.email_verify end},
      guest: %{
        name: "Guest",
        value: fn x -> x.is_guest end,
        filters: [{"Guest users", true}, {"Users", false}]
      },
      signed_in_at: %{name: "Signed In At", value: fn x -> convert_utc_time(x.signed_in_at) end},
      inserted_at: %{name: "Created At", value: fn x -> x.inserted_at end},
      updated_at: %{name: "Updated At", value: fn x -> x.updated_at end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      email: %{label: "Email"}
    ]
  end

  def ordering(_schema) do
    # order by created_at
    [desc: :inserted_at]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:roles])
  end

  def resource_actions(_conn) do
    [
      resend_verification: %{
        name: "Resend Email Verification",
        action: fn _, user -> resend_email_verification(user) end
      },
      resend_set_password: %{
        name: "Resend Set Password",
        action: fn _, user -> resend_set_password(user) end
      }
    ]
  end

  def custom_links(_schema) do
    [
      %{
        name: "Logout",
        url: Routes.session_path(WraftDocWeb.Endpoint, :delete),
        method: :delete,
        order: 3,
        location: :bottom,
        icon: "user-circle",
        full_icon: "flag-full"
      }
    ]
  end

  defp resend_email_verification(user) do
    AuthTokens.create_token_and_send_email(user.email)
    {:ok, user}
  end

  defp resend_set_password(user) do
    token = AuthTokens.create_set_password_token(user)

    # Send email notification
    %{name: user.name, email: user.email, token: token.value}
    |> EmailWorker.new(queue: "mailer", tags: ["waiting_list_acceptance"])
    |> Oban.insert()

    {:ok, user}
  end

  defp convert_utc_time(nil), do: nil

  defp convert_utc_time(datetime) do
    Account.convert_utc_time(datetime, "Asia/Calcutta")
  end

  def delete(_conn, %{data: user} = _changeset) do
    %{user: user, organisation: personal_org} =
      Enterprise.get_personal_organisation_and_role(user)

    Repo.delete(personal_org)
    Repo.delete(user)
  end
end
