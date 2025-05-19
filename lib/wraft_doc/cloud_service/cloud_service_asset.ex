defmodule WraftDoc.CloudService.CloudServiceAsset do
  @moduledoc """
  Schema for Cloud Service Assets
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :google_drive_id,
             :name,
             :mime_type,
             :size,
             :created_time,
             :modified_time,
             :description,
             :file_extension
           ]}
  schema "cloud_service_assets" do
    field(:google_drive_id, :string)
    field(:name, :string)
    field(:mime_type, :string)
    field(:size, :integer)
    field(:description, :string)
    field(:created_time, :utc_datetime)
    field(:modified_time, :utc_datetime)
    field(:file_extension, :string)
    field(:owners, {:array, :map})
    field(:parents, {:array, :string})

    timestamps()
  end

  def changeset(file, attrs) do
    file
    |> cast(attrs, [
      :google_drive_id,
      :name,
      :mime_type,
      :description,
      :size,
      :created_time,
      :modified_time,
      :owners,
      :parents,
      :file_extension
    ])
    |> validate_required([:google_drive_id, :name])
    |> unique_constraint(:google_drive_id)
  end
end
