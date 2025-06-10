defmodule WraftDoc.Storage.AccessLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storage_access_logs" do
    field :success, :boolean, default: false
    field :metadata, :map
    field :action, :string
    field :session_id, :string
    field :ip_address, :string
    field :user_agent, :string
    field :storage_item_id, :binary_id
    field :storage_asset_id, :binary_id
    field :user_id, :binary_id
    field :repository_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(access_log, attrs) do
    access_log
    |> cast(attrs, [:action, :ip_address, :user_agent, :session_id, :metadata, :success])
    |> validate_required([:action, :ip_address, :user_agent, :session_id, :success])
  end
end
