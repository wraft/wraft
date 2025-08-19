defmodule WraftDocWeb.Api.V1.IntegrationAuthController do
  use WraftDocWeb, :controller
  alias WraftDoc.Integrations.DocuSign

  def auth(conn, _params) do
    organisation_id = conn.assigns.current_user.current_org_id
    authorize_url = DocuSign.get_authorization_url(organisation_id)

    json(conn, %{
      status: "success",
      redirect_url: authorize_url
    })
  end

  def callback(conn, %{"code" => code}) do
    organisation_id = conn.assigns.current_user.current_org_id
    user = conn.assigns[:current_user]
    DocuSign.handle_callback(user, organisation_id, %{"code" => code})

    redirect(conn, to: "/")
  end

  # def status(conn, %{"id" => id}) do
  #   organisation_id = conn.assigns.current_user.current_org_id

  #   try do
  #     integration = DocuSign.get_integration!(id)

  #     if integration.organisation_id != organisation_id do
  #       conn
  #       |> put_status(:forbidden)
  #       |> json(%{error: "Integration does not belong to current organization"})
  #     else
  #       render(conn, "show.json", integration: integration)
  #     end
  #   rescue
  #     Ecto.NoResultsError ->
  #       conn
  #       |> put_status(:not_found)
  #       |> json(%{error: "Integration not found"})
  #   end
  # end
end
