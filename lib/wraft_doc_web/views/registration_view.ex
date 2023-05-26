defmodule WraftDocWeb.Api.V1.RegistrationView do
  @moduledoc """
  View module for registration controller.
  """
  use WraftDocWeb, :view

  def render("create.json", %{
        user: user,
        access_token: access_token,
        refresh_token: refresh_token,
        organisations: organisations
      }) do
    %{
      access_token: access_token,
      refresh_token: refresh_token,
      user: %{
        id: user.id,
        name: user.name,
        email: user.email,
        email_verify: user.email_verify,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
        # TODO
        #  roles: render_many(user.roles, __MODULE__, "role.json", as: :role)
      },
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
