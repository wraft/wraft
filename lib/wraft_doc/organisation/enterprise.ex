defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto.Query
  import Ecto

  alias WraftDoc.{Repo, Enterprise.Flow, Enterprise.Organisation, Account.User}

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
  @spec create_flow(%User{}, %Organisation{}, map) ::
          %Flow{creator: %User{}} | {:error, Ecto.Changeset.t()}
  def create_flow(current_user, organisation, params) do
    current_user
    |> build_assoc(:flows, organisation: organisation)
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

  @doc """
  Delete a flow.
  """
  @spec delete_flow(%Flow{}) :: {:ok, %Flow{}} | {:error, Ecto.Changeset.t()}
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

  @doc """
  Shuffle the order of flows.
  """
  @spec shuffle_order(%Flow{}, integer) :: list
  def shuffle_order(%{order: order, organisation_id: org_id}, additive) do
    from(f in Flow, where: f.organisation_id == ^org_id and f.order > ^order)
    |> Repo.all()
    |> Task.async_stream(fn x -> update_flow_order(x, additive) end)
    |> Enum.to_list()
  end

  # Update the flow order by adding the additive.
  @spec update_flow_order(%Flow{}, integer) :: {:ok, %Flow{}}
  defp update_flow_order(%{order: order} = flow, additive) do
    flow
    |> Flow.order_update_changeset(%{order: order + additive})
    |> Repo.update()
  end

  @doc """
  Get an organisation from its UUID.
  """
  @spec get_organisation(binary) :: %Organisation{} | nil
  def get_organisation(org_uuid) do
    Repo.get_by(Organisation, uuid: org_uuid)
  end
end
