defmodule WraftDocWeb.Plug.ValidMembershipCheck do
  @moduledoc """
  Plug to check if user has valid subscription.
  """

  import Plug.Conn

  alias WraftDoc.Billing
  alias WraftDoc.Enterprise

  def init(_params) do
  end

  def call(%Plug.Conn{params: %{"auth_type" => _}} = conn, _opts), do: conn

  def call(conn, _params) do
    user = conn.assigns[:current_user]

    if Enterprise.self_hosted?() do
      conn
    else
      if user && user.current_org_id do
        valid_subscription?(conn, user)
      else
        conn
      end
    end
  end

  defp valid_subscription?(conn, user) do
    # Allow personal organisations even without valid subscription
    if personal_organisation?(user.current_org_id) do
      conn
    else
      case Billing.has_valid_subscription?(user.current_org_id) do
        true -> conn
        _ -> error_response(conn)
      end
    end
  end

  defp personal_organisation?(organisation_id) do
    case Enterprise.get_organisation(organisation_id) do
      %{name: "Personal"} -> true
      nil -> false
      _ -> false
    end
  rescue
    _ -> false
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
