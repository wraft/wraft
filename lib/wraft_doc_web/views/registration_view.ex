defmodule WraftDocWeb.Api.V1.RegistrationView do
  @moduledoc """
  View module for registration controller.
  """
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.UserView

  def render("create.json", %{
        user: user,
        access_token: access_token,
        refresh_token: refresh_token,
        organisations: organisations
      }) do
    %{
      access_token: access_token,
      refresh_token: refresh_token,
      user: render_one(user, UserView, "login_user.json", as: :user),
      organisations:
        render_many(organisations, __MODULE__, "organisation.json", as: :organisation)
    }
  end

  def render("organisation.json", %{organisation: organisation}) do
    %{id: organisation.id, name: organisation.name}
  end

  def render("role.json", %{role: role}) do
    %{id: role.id, name: role.name}
  end
end
