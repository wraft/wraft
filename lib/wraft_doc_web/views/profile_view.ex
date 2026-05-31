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
      profile_pic_thumb: generate_url(profile, :thumb),
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
      profile_pic_thumb: generate_url(user.profile, :thumb),
      user: render_one(user, UserView, "user_id_and_email.json", as: :user)
    }
  end

  def render("base_profile.json", %{profile: profile}) do
    %{
      id: profile.id,
      name: profile.name,
      dob: profile.dob,
      gender: profile.gender,
      profile_pic: generate_url(profile),
      profile_pic_thumb: generate_url(profile, :thumb)
    }
  end

  def generate_url(profile, version \\ :original)

  def generate_url(%{profile_pic: pic} = profile, version) do
    WraftDocWeb.PropicUploader.url({pic, profile}, version, signed: true)
  end

  def generate_url(_, _version), do: nil
end
