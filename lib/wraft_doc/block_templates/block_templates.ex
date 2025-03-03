defmodule WraftDoc.BlockTemplates do
  @moduledoc """
  Provides functions to manage block templates including creation, retrieval, updates, and deletions.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.Repo
  alias WraftDoc.Utils.CSVHelper

  @doc """
  Creates block templates in bulk from the file given.
  """
  @spec block_template_bulk_insert(User.t(), map, String.t()) ::
          [{:ok, BlockTemplate.t()}] | {:error, :not_found}
  ## TODO - improve tests
  def block_template_bulk_insert(%User{} = current_user, mapping, path) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = Map.keys(mapping)

    path
    |> CSVHelper.decode_csv(mapping_keys)
    |> Stream.map(fn x -> bulk_b_temp_creation(x, current_user, mapping) end)
    |> Enum.to_list()
  end

  def block_template_bulk_insert(_, _, _), do: {:error, :not_found}

  @doc """
  Create a block template
  """
  # TODO - improve tests
  @spec create_block_template(User.t(), map) :: BlockTemplate.t()
  def create_block_template(%{current_org_id: org_id} = current_user, params) do
    current_user
    |> build_assoc(:block_templates, organisation_id: org_id)
    |> BlockTemplate.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, block_template} ->
        Repo.preload(block_template, [{:creator, :profile}])

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_block_template(_, _), do: {:error, :fake}

  @doc """
  Get a block template by its uuid
  """
  @spec get_block_template(Ecto.UUID.t(), BlockTemplate.t()) :: BlockTemplate.t()
  def get_block_template(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(BlockTemplate, id: id, organisation_id: org_id) do
      %BlockTemplate{} = block_template -> Repo.preload(block_template, [{:creator, :profile}])
      _ -> {:error, :invalid_id, "BlockTemplate"}
    end
  end

  def get_block_template(<<_::288>>, _), do: {:error, :invalid_id, "BlockTemplate"}
  def get_block_template(_, %{current_org_id: _org_id}), do: {:error, :fake}
  def get_block_template(_, _), do: {:error, :invalid_id, "BlockTemplate"}

  @doc """
  Updates a block template
  """
  @spec update_block_template(BlockTemplate.t(), map) :: BlockTemplate.t()
  def update_block_template(block_template, params) do
    block_template
    |> BlockTemplate.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, block_template} ->
        Repo.preload(block_template, [{:creator, :profile}])
    end
  end

  @doc """
  Delete a block template
  """
  @spec delete_block_template(BlockTemplate.t()) :: {:ok, BlockTemplate.t()}
  def delete_block_template(%BlockTemplate{} = block_template), do: Repo.delete(block_template)

  def delete_block_template(_), do: {:error, :fake}

  @doc """
  Index of a block template by organisation
  """
  @spec index_block_template(User.t(), map) :: List.t()
  def index_block_template(%{current_org_id: org_id}, params) do
    BlockTemplate
    |> where([bt], bt.organisation_id == ^org_id)
    |> preload([bt], creator: [:profile])
    |> order_by([bt], desc: bt.id)
    |> Repo.paginate(params)
  end

  @spec bulk_b_temp_creation(map, User.t(), map) :: BlockTemplate.t()
  defp bulk_b_temp_creation(data, user, mapping) do
    params = CSVHelper.update_keys(data, mapping)
    create_block_template(user, params)
  end
end
