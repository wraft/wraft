defmodule WraftDocWeb.Plug.ValidMembershipCheck do
  @moduledoc """
  Plug to check if user has valid membership.
  """

  import Plug.Conn

  alias WraftDoc.{Enterprise, Repo}

  def init(_params) do
  end

  def call(conn, _params) do
    user = conn.assigns[:current_user]

    case Enum.member?(user.role_names, "super_admin") do
      true ->
        conn

      _ ->
        has_valid_membership?(conn, user)
    end
  end

  # Checks if the user's organisation has a valid membership.
  defp has_valid_membership?(conn, user) do
    user = Repo.preload(user, [:organisation])

    case Enterprise.get_organisation_membership(user.organisation.id) do
      %{is_expired: is_expired} ->
        case is_expired do
          false ->
            conn

          true ->
            body =
              Jason.encode!(%{
                errors:
                  "You do not have a valid membership. Upgrade your membership to continue.!"
              })

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, body)
            |> halt()
        end

      _ ->
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
