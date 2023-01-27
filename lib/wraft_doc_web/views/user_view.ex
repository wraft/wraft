defmodule WraftDocWeb.Api.V1.UserView do
  @moduledoc """
  View module for user controller.
  """
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.InstanceApprovalSystemView
  alias WraftDocWeb.Api.V1.ProfileView
  alias __MODULE__

  def render("sign-in.json", %{token: token, user: user}) do
    %{
      token: token,
      user: render_one(user, UserView, "user.json", as: :user)
    }
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      email_verify: user.email_verify,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  def render("remove.json", %{user: user}) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      email_verify: user.email_verify,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at,
      deleted_at: user.deleted_at
    }
  end

  def render("index.json", %{
        users: users,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      users: render_many(users, UserView, "user.json", as: :user),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("user_id_and_email.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email
    }
  end

  def render("user_id_and_name.json", %{user: user}) do
    %{
      id: user.id,
      name: user.name,
      profile_pic: generate_url(user.profile)
    }
  end

  def render("me.json", %{user: me, instance_approval_systems: instance_approval_systems}) do
    %{
      id: me.id,
      name: me.name,
      email: me.email,
      email_verify: me.email_verify,
      organisation_id: me.current_org_id,
      inserted_at: me.inserted_at,
      updated_at: me.updated_at,
      profile_pic: generate_url(me.profile),
      # TODO uncomment this once RBAC is done succefully
      # roles: render_many(me.roles, RegistrationView, "role.json", as: :role),
      instances_to_approve:
        render_many(
          instance_approval_systems,
          InstanceApprovalSystemView,
          "show_instance_state.json",
          as: :instance_approval_system
        )
    }
  end

  def render("show.json", %{user: me}) do
    %{
      id: me.id,
      name: me.name,
      email: me.email,
      email_verify: me.email_verify,
      organisation_id: me.organisation.id,
      inserted_at: me.inserted_at,
      updated_at: me.updated_at,
      profile_pic: generate_url(me.profile)
      # TODO uncomment this once RBAC is done succefully
      # roles: render_many(me.roles, RegistrationView, "role.json", as: :role)
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
    %{
      action: activity.action,
      object: activity.object,
      meta: activity.meta,
      inserted_at: activity.inserted_at,
      actor: render_one(activity.actor, __MODULE__, "user.json", as: :user),
      actor_profile: render_one(activity.profile, ProfileView, "base_profile.json", as: :profile)
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
   Verification of user email address
  """
  def render("check_email_token.json", %{verification_status: status}) do
    %{
      info: "Email Verified",
      verification_status: status
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

  # defp get_object_data(%{name: name, id: id}, _meta) do
  #   %{
  #     id: id,
  #     name: name
  #   }
  # end

  # defp get_object_data(%{title: name, id: id}, _meta) do
  #   %{
  #     id: id,
  #     name: name
  #   }
  # end

  # defp get_object_data(%{instance_id: name, id: id}, _meta) do
  #   %{
  #     id: id,
  #     name: name
  #   }
  # end

  # defp get_object_data(%{state: name, id: id}, _meta) do
  #   %{
  #     id: id,
  #     name: name
  #   }
  # end

  # defp get_object_data(map) when is_map(map) do
  #   map
  # end

  # defp get_object_data(_, meta) do
  #   Map.new(meta, fn {_, address} -> {:name, address} end)
  # end

  def generate_url(%{profile_pic: pic} = profile) do
    WraftDocWeb.PropicUploader.url({pic, profile})
  end

  def generate_url(_), do: nil
end
