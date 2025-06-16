defmodule WraftDoc.CloudImport.CloudImportAsset do
  @moduledoc """
  Schema for Cloud Service Assets
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :cloud_service,
             :file_type,
             :size,
             :created_time,
             :modified_time,
             :description,
             :file_extension
           ]}
  schema "cloud_import_assets" do
    field(:name, :string)
    field(:cloud_service, :string)
    field(:file_type, :string)
    field(:size, :integer)
    field(:description, :string)
    field(:created_time, :utc_datetime)
    field(:modified_time, :utc_datetime)
    field(:file_extension, :string)
    field(:owners, {:array, :map})
    field(:parents, {:array, :string})
    belongs_to(:user_id, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(file, attrs) do
    file
    |> cast(attrs, [
      :name,
      :cloud_service,
      :file_type,
      :description,
      :size,
      :created_time,
      :modified_time,
      :owners,
      :parents,
      :file_extension
    ])
    |> validate_required([:name])
  end
end
