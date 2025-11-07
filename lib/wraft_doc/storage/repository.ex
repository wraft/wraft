defmodule WraftDoc.Storages.Repository do
  @moduledoc """
  The sync job model.
  Represents a repository in the storage system, including metadata such as
  name, description, storage limit, and current storage used.
  It also maintains relationships with the user who created it and the organisation it belongs to.
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation

  @foreign_key_type :binary_id

  schema "repositories" do
    field(:name, :string)
    field(:status, :string)
    field(:description, :string)
    field(:storage_limit, :integer)
    field(:current_storage_used, :integer)
    field(:item_count, :integer)
    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)

    timestamps()
  end

  @doc false
  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [
      :name,
      :description,
      :storage_limit,
      :current_storage_used,
      :item_count,
      :status,
      :organisation_id,
      :creator_id
    ])
    |> validate_required([
      :name,
      :storage_limit,
      :current_storage_used,
      :item_count,
      :status,
      :organisation_id,
      :creator_id
    ])
  end
end
