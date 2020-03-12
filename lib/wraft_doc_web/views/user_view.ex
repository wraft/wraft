defmodule WraftDocWeb.Api.V1.UserView do
  @moduledoc """
  View module for user controller.
  """
  use WraftDocWeb, :view

  def render("sign-in.json", %{token: token, user: user}) do
    %{
      token: token,
      user: %{
        id: user.uuid,
        name: user.name,
        email: user.email,
        email_verify: user.email_verify,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      }
    }
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.uuid,
      name: user.name,
      email: user.email,
      email_verify: user.email_verify,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  def render("me.json", %{user: me}) do
    %{
      id: me.uuid,
      name: me.name,
      email: me.email,
      email_verify: me.email_verify,
      organisation_id: me.organisation.uuid,
      inserted_at: me.inserted_at,
      updated_at: me.updated_at,
      profile_pic: me.profile.profile_pic,
      role: me.role.name
    }
  end
end
