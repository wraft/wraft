defmodule WraftDoc.Workflows.Actions.ActionSettings do
  @moduledoc """
  Context for managing action settings (custom action configs per organization).
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.Actions.ActionSetting

  @doc """
  Create or update an action setting.
  """
  @spec upsert_action_setting(User.t(), String.t(), map()) ::
          {:ok, ActionSetting.t()} | {:error, Ecto.Changeset.t()}
  def upsert_action_setting(%User{current_org_id: org_id}, action_id, attrs) do
    case get_setting(org_id, action_id) do
      nil ->
        %ActionSetting{}
        |> ActionSetting.changeset(
          attrs
          |> Map.put("action_id", action_id)
          |> Map.put("organisation_id", org_id)
        )
        |> Repo.insert()

      setting ->
        setting
        |> ActionSetting.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Get action setting for an organization.
  """
  @spec get_setting(Ecto.UUID.t(), String.t()) :: ActionSetting.t() | nil
  def get_setting(org_id, action_id) do
    ActionSetting
    |> where([a], a.organisation_id == ^org_id and a.action_id == ^action_id)
    |> Repo.one()
  end

  @doc """
  List all action settings for an organization.
  """
  @spec list_settings(Ecto.UUID.t()) :: [ActionSetting.t()]
  def list_settings(org_id) do
    ActionSetting
    |> where([a], a.organisation_id == ^org_id)
    |> Repo.all()
  end

  @doc """
  Delete an action setting.
  """
  @spec delete_setting(User.t(), String.t()) ::
          {:ok, ActionSetting.t()} | {:error, Ecto.Changeset.t()}
  def delete_setting(%User{current_org_id: org_id}, action_id) do
    case get_setting(org_id, action_id) do
      nil -> {:error, :not_found}
      setting -> Repo.delete(setting)
    end
  end
end
