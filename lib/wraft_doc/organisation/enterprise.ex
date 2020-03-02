defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto

  alias WraftDoc.{Repo, Enterprise.Flow, Account.User}

  @doc """
  Get a flow from its UUID.
  """
  @spec get_flow(binary) :: %Flow{} | nil
  def get_flow(flow_uuid) do
    Repo.get_by(Flow, uuid: flow_uuid)
  end

  @doc """
  Create a flow.
  """
  @spec create_flow(%User{}, map) :: %Flow{creator: %User{}} | {:error, Ecto.Changeset.t()}
  def create_flow(current_user, params) do
    current_user
    |> build_assoc(:flows)
    |> Flow.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, flow} ->
        flow |> Repo.preload(:creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  List of all flows.
  """
  @spec flow_index() :: list
  def flow_index() do
    Flow |> Repo.all() |> Repo.preload(:creator)
  end

  @doc """
  Update a flow.
  """
  @spec update_flow(%Flow{}, map) :: %Flow{} | {:error, Ecto.Changeset.t()}
  def update_flow(flow, params) do
    flow
    |> Flow.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, flow} ->
        flow |> Repo.preload(:creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @spec delete_flow(%Flow{}) :: %Flow{} | {:error, Ecto.Changeset.t()}
  def delete_flow(flow) do
    flow
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the flow. Some Contents depend on this flow. Update those contents and then try again.!"
    )
    |> Repo.delete()
  end
end
