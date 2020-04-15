defmodule WraftDocWeb.Api.V1.ProfileView do
  @moduledoc """
  View module for Profile controller.
  """
  use WraftDocWeb, :view

  def render("profile.json", %{profile: profile}) do
    %{
      uuid: profile.uuid,
      name: profile.name,
      dob: profile.dob,
      gender: profile.gender,
      profile_pic: profile.profile_pic,
      # country: %{
      #   id: profile.country.uuid,
      #   country_name: profile.country.country_name,
      #   country_code: profile.country.country_code,
      #   calling_code: profile.country.calling_code
      # },
      user: %{id: profile.user.uuid, email: profile.user.email}
    }
  end
end
