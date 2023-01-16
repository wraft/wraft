defmodule WraftDocWeb.Plug.ValidMembershipCheck do
  @moduledoc """
  Plug to check if user has valid membership.
  """

  import Plug.Conn

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    user = conn.assigns[:current_user]

    case is_personal_org?(user) do
      false -> has_valid_membership?(conn, user)
      true -> conn
    end
  end

  # Checks if the user's organisation has a valid membership.
  defp has_valid_membership?(conn, user) do
    case Enterprise.get_organisation_membership(user.current_org_id) do
      %{is_expired: false} -> conn
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
        errors: "You do not have a valid membership. Upgrade your membership to continue.!"
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, body)
    |> halt()
  end
end
