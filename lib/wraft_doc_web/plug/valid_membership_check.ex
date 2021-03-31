defmodule WraftDocWeb.Plug.ValidMembershipCheck do
  @moduledoc """
  Plug to check if user has valid membership.
  """

  import Plug.Conn

  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise
  alias WraftDoc.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    user = conn.assigns[:current_user]
    %User{role: %{name: role_name}} = user

    case role_name do
      "admin" ->
        conn

      _ ->
        has_valid_membership?(conn, user)
    end
  end

  # Checks if the user's organisation has a valid membership.
  defp has_valid_membership?(conn, user) do
    user = Repo.preload(user, [:organisation])
    %{is_expired: is_expired} = Enterprise.get_organisation_membership(user.organisation.uuid)

    case is_expired do
      false ->
        conn

      true ->
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
end
