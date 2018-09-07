defmodule StarterWeb.Api.V1.ProfileView do
    @moduledoc """
    View module for Profile controller.
    """
    use StarterWeb, :view
    alias StarterWeb.ProfileView
  require IEx
    def render("profile.json", %{profile: profile}) do
      %{
        firstname: profile.firstname,
        lastname: profile.lastname,
        dob: profile.dob,
        gender: profile.gender,
        marital_status: profile.marital_status,
        current_location: profile.current_location,
        address: profile.address,
        pin: profile.pin,
        profile_pic: profile.profile_pic,
        country: %{id: profile.country.id, country_name: profile.country.country_name, country_code: profile.country.country_code, calling_code: profile.country.calling_code},    
        user: %{id: profile.user.id, mobile: profile.user.mobile, email: profile.user.email}
      }
    end
  end