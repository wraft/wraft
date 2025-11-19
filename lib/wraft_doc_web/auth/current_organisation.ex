defmodule WraftDocWeb.CurrentOrganisation do
  @moduledoc """
    This plug stores the current organisation id and the
    user's permissions in the current organisation in the user struct
    based on what is found in the claims.
  """
  import Ecto.Query
  import Guardian.Plug
  import Plug.Conn

  alias WraftDoc.Account.Role
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  alias WraftDocWeb.Guardian.AuthErrorHandler

  def init(opts), do: opts

  def call(
        %Plug.Conn{params: %{"auth_type" => _}, assigns: %{current_user: current_user}} =
          conn,
        _opts
      ) do
    current_user
    |> Map.merge(%{current_org_id: nil})
    |> then(&assign(conn, :current_user, &1))
  end

  def call(conn, _opts) do
    # If current_user already has org_id (e.g., from API key auth), skip Guardian processing
    if conn.assigns[:current_user] && conn.assigns.current_user.current_org_id do
      conn
    else
      process_jwt_org(conn)
    end
  end

  defp process_jwt_org(conn) do
    %{"organisation_id" => org_id} = current_claims(conn)

    case Repo.get(Organisation, org_id) do
      nil ->
        AuthErrorHandler.auth_error(conn, {:error, :no_org})

      %Organisation{} ->
        roles_preload_query = from(r in Role, where: r.organisation_id == ^org_id)
        user = Repo.preload(conn.assigns[:current_user], roles: roles_preload_query)

        %{names: role_names, permissions: permissions} =
          Enum.reduce(user.roles, %{names: [], permissions: []}, fn role, acc ->
            add_role_names_and_permissions(role, acc)
          end)

        user =
          Map.merge(user, %{
            current_org_id: org_id,
            role_names: role_names,
            permissions: permissions
          })

        assign(conn, :current_user, user)
    end
  end

  # Private
  defp add_role_names_and_permissions(role, roles_acc) do
    permissions = roles_acc.permissions |> Kernel.++(role.permissions) |> Enum.uniq()
    names = [role.name | roles_acc.names]
    %{names: names, permissions: permissions}
  end
end
