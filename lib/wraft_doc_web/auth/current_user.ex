defmodule WraftDocWeb.CurrentUser do
  @moduledoc """
  This is a plug that stores the current user details in the
  conn based on the subject in the JWT token.
  """
  import Plug.Conn
  import Guardian.Plug
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Documents.InstanceApprovalSystem
  alias WraftDoc.Repo

  alias WraftDocWeb.Guardian.AuthErrorHandler

  def init(opts), do: opts

  def call(conn, _opts) do
    # If current_user is already set (e.g., by API key auth), skip Guardian processing
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> maybe_add_auth_type()
      |> add_current_user()
    end
  end

  defp maybe_add_auth_type(%{params: params} = conn) do
    conn
    |> current_claims()
    |> add_type_to_params(conn, params)
  end

  defp add_type_to_params(%{"type" => type}, conn, params),
    do: %{conn | params: Map.put(params, "auth_type", type)}

  defp add_type_to_params(_claims, conn, _params),
    do: conn

  defp add_current_user(conn) do
    conn
    |> current_resource()
    |> case do
      nil -> AuthErrorHandler.auth_error(conn, {:error, :no_user})
      email -> get_user(email)
    end
    |> case do
      %Plug.Conn{} = conn -> conn
      nil -> AuthErrorHandler.auth_error(conn, {:error, :no_user})
      user -> assign(conn, :current_user, preload_user_data(user))
    end
  end

  defp get_user(email) when is_binary(email), do: Repo.get_by(User, email: email)
  defp get_user(_), do: nil

  defp preload_user_data(user) do
    instances_to_approve = from(ias in InstanceApprovalSystem, where: ias.flag == false)
    Repo.preload(user, [:profile, instances_to_approve: instances_to_approve])
  end
end
