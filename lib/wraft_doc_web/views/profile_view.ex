defmodule WraftDocWeb.Api.V1.ProfileView do
  @moduledoc """
  View module for Profile controller.
  """
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.UserView

  def render("profile.json", %{profile: profile}) do
    %{
      id: profile.id,
      name: profile.name,
      dob: profile.dob,
      gender: profile.gender,
      profile_pic: generate_url(profile),
      user: render_one(profile.user, UserView, "user_id_and_email.json", as: :user)
    }
  end

  def render("current_profile.json", %{user: user}) do
    %{
      id: user.profile.id,
      name: user.profile.name,
      dob: user.profile.dob,
      gender: user.profile.gender,
      profile_pic: generate_url(user.profile),
      user: render_one(user, UserView, "user_id_and_email.json", as: :user)
    }
  end

  def render("base_profile.json", %{profile: profile}) do
    %{
      id: profile.id,
      name: profile.name,
      dob: profile.dob,
      gender: profile.gender,
      profile_pic: generate_url(profile)
    }
  end

  def generate_url(%{profile_pic: pic} = profile) do
    WraftDocWeb.PropicUploader.url({pic, profile}, signed: true)
  end
end
