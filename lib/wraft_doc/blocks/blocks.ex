defmodule WraftDoc.Blocks do
  @moduledoc """
    The block context.
  """

  alias Ecto.Multi
  alias WraftDoc.Blocks.Block
  alias WraftDoc.Repo

  @doc """
  Create a Block
  """
  @spec create_block(User.t(), map) :: Block.t()
  def create_block(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id, "creator_id" => current_user.id})

    Multi.new()
    |> Multi.insert(:block, Block.changeset(%Block{}, params))
    |> Multi.update(:block_input, &Block.block_input_changeset(&1.block, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{block_input: block}} -> block
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def create_block(_, _), do: {:error, :fake}

  @doc """
  Get a block by id
  """
  @spec get_block(Ecto.UUID.t(), User.t()) :: Block.t()
  def get_block(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Block, id: id, organisation_id: org_id) do
      %Block{} = block -> block
      _ -> {:error, :invalid_id, "Block"}
    end
  end

  def get_block(<<_::288>>, _), do: {:error, :fake}
  def get_block(_, %{current_org_id: _}), do: {:error, :invalid_id, "Block"}

  @doc """
  Update a block
  """
  def update_block(%Block{} = block, params) do
    block
    |> Block.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, block} ->
        block

      {:error, _} = changeset ->
        changeset
    end
  end

  def update_block(_, _), do: {:error, :fake}

  @doc """
  Delete a block
  """
  def delete_block(%Block{} = block) do
    Repo.delete(block)
  end
end
