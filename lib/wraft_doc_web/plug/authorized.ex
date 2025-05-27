defmodule WraftDocWeb.Plug.Authorized do
  @moduledoc """
  Checks if the user has permissions to perform an action.
  If the user has superadmin role, we assume they have access to everything.
  If the action doesnt have a permission listed in the controller, we assume
  every user has acces to it.
  """
  import Plug.Conn
  alias WraftDoc.Account.User
  alias WraftDoc.Documents
  @superadmin_role "superadmin"

  def init(opts), do: opts

  # If the user is a guest, we dont need to check for permissions
  # like for the regular user. [RBAC]
  # TODO need to remove since we are passing the guest access type within the token
  # for all /guest/ paths
  def call(%Plug.Conn{path_info: ["api", "v1", "guest" | _]} = conn, _opts) do
    conn
  end

  def call(
        %Plug.Conn{
          params: %{"auth_type" => "sign", "id" => document_id},
          assigns: %{current_user: current_user}
        } = conn,
        _opts
      ) do
    case Documents.has_access?(current_user, document_id, :counterparty) do
      true ->
        conn

      _ ->
        body = Jason.encode!(%{errors: "Unauthorized access.!"})

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, body)
        |> halt()
    end
  end

  def call(
        %Plug.Conn{
          params: %{"auth_type" => "guest", "id" => document_id},
          assigns: %{current_user: current_user}
        } = conn,
        _opts
      ) do
    case Documents.has_access?(current_user, document_id) do
      true ->
        conn

      _ ->
        body = Jason.encode!(%{errors: "Unauthorized access.!"})

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, body)
        |> halt()
    end
  end

  def call(%Plug.Conn{private: %{phoenix_action: action}} = conn, opts) do
    case Keyword.get(opts, action) do
      nil ->
        conn

      required_permission ->
        %User{permissions: permissions, role_names: role_names} = conn.assigns.current_user

        if @superadmin_role in role_names do
          conn
        else
          check_permission(conn, required_permission, permissions)
        end
    end
  end

  # Private
  defp check_permission(conn, required_permission, users_permissions) do
    case required_permission in users_permissions do
      true ->
        conn

      false ->
        body = Jason.encode!(%{errors: "Unauthorized access.!"})

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, body)
        |> halt()
    end
  end
end
