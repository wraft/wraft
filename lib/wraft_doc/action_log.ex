defmodule WraftDoc.ActionLog do
  @moduledoc """
  The action log model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "action_log" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:actor, :map, default: %{})
    field(:remote_ip, :string)
    field(:actor_agent, :string)
    field(:request_path, :string)
    field(:request_method, :string)
    field(:action, :string)
    field(:params, :map, default: %{})
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def authorized_action_changeset(log, attrs \\ %{}) do
    log
    |> cast(attrs, [
      :actor,
      :remote_ip,
      :actor_agent,
      :request_path,
      :request_method,
      :action,
      :params,
      :user_id
    ])
    |> validate_required([
      :actor,
      :remote_ip,
      :request_path,
      :request_method,
      :action,
      :user_id
    ])
  end

  def unauthorized_action_changeset(log, attrs \\ %{}) do
    log
    |> cast(attrs, [:remote_ip, :actor_agent, :request_path, :request_method, :action, :params])
    |> validate_required([:remote_ip, :request_path, :request_method, :action])
  end
end
