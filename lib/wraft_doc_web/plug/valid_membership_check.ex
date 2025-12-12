defmodule WraftDocWeb.Plug.ValidMembershipCheck do
  @moduledoc """
  Plug to check if user has valid subscription.
  """

  import Plug.Conn

  alias WraftDoc.Enterprise

  def init(_params) do
  end

  def call(%Plug.Conn{params: %{"auth_type" => _}} = conn, _opts), do: conn

  def call(conn, _params) do
    user = conn.assigns[:current_user]

    if Enterprise.self_hosted?() do
      conn
    else
      valid_membership?(conn, user)
    end
  end

  defp valid_membership?(conn, user) do
    organisation = Enterprise.get_organisation(user.current_org_id)

    if organisation && organisation.name == "Personal" do
      conn
    else
      case Enterprise.get_organisation_membership(user.current_org_id) do
        %Enterprise.Membership{is_expired: false} -> conn
        _ -> error_response(conn)
      end
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
