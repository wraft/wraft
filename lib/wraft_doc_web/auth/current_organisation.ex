defmodule WraftDocWeb.CurrentOrganisation do
  @moduledoc """
    This plug stores the current organisation id in the user struct
    based on what is found in the claims.
  """
  import Plug.Conn
  import Guardian.Plug

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  alias WraftDocWeb.Guardian.AuthErrorHandler

  def init(opts), do: opts

  def call(conn, _opts) do
    %{"organisation_id" => org_id} = current_claims(conn)

    case Repo.get(Organisation, org_id) do
      nil ->
        AuthErrorHandler.auth_error(conn, {:error, :no_org})

      %Organisation{} ->
        user = conn.assigns[:current_user]
        user = Map.put(user, :current_org_id, org_id)
        assign(conn, :current_user, user)
    end
  end
end
