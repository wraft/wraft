defmodule WraftDocWeb.Plug.ValidMembershipCheck do
  @moduledoc """
  Plug to check if user has valid subscription.
  """

  import Plug.Conn

  alias WraftDoc.Billing
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    user = conn.assigns[:current_user]

    case is_personal_org?(user) do
      false -> has_valid_subscription?(conn, user)
      true -> conn
    end
  end

  defp has_valid_subscription?(conn, user) do
    case Billing.has_active_subscription?(user.current_org_id) do
      true -> conn
      _ -> error_response(conn)
    end
  end

  defp is_personal_org?(user) do
    case Repo.get_by(Organisation, id: user.current_org_id, name: "Personal") do
      %Organisation{} -> true
      nil -> false
    end
  end

  defp error_response(conn) do
    body =
      Jason.encode!(%{
        errors: "You do not have a valid subscription. Upgrade your subscription to continue.!"
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, body)
    |> halt()
  end
end
