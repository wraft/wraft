defmodule WraftDocWeb.Api.V1.UserView do
  @moduledoc """
  View module for user controller.
  """
  use WraftDocWeb, :view
  alias __MODULE__

  def render("sign-in.json", %{token: token, user: user}) do
    %{
      token: token,
      user: render_one(user, UserView, "user.json", as: :user)
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

  def render("activities.json", %{
        activities: activities,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      activities: render_many(activities, UserView, "activity.json", as: :activity),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("activity.json", %{activity: activity}) do
    actor = get_actor_name(activity.actor)
    object_details = get_object_data(activity.object_struct, activity.meta)

    %{
      action: activity.action,
      object: activity.object,
      meta: activity.meta,
      inserted_at: activity.inserted_at,
      actor: actor,
      object_details: object_details
    }
  end

  @doc """
   Auth token for reseting password
  """
  def render("auth_token.json", %{auth_token: _}) do
    %{
      info: "A password reset link has been sent to your email.!"
    }
  end

  @doc """
  Guardian token generated after verifying auth_token
  """
  def render("check_token.json", %{token: _}) do
    %{
      info: "Approved"
    }
  end

  @doc """
  Token verified information
  """
  def render("token_verified.json", %{info: info}) do
    %{
      info: info
    }
  end

  defp get_actor_name(%{name: name}), do: name
  defp get_actor_name(nil), do: nil

  defp get_object_data(%{name: name, uuid: uuid}, _meta) do
    %{
      id: uuid,
      name: name
    }
  end

  defp get_object_data(%{title: name, uuid: uuid}, _meta) do
    %{
      id: uuid,
      name: name
    }
  end

  defp get_object_data(%{instance_id: name, uuid: uuid}, _meta) do
    %{
      id: uuid,
      name: name
    }
  end

  defp get_object_data(%{state: name, uuid: uuid}, _meta) do
    %{
      id: uuid,
      name: name
    }
  end

  # defp get_object_data(map) when is_map(map) do
  #   map
  # end

  defp get_object_data(_, meta) do
    Map.new(meta, fn {_, address} -> {:name, address} end)
  end
end
