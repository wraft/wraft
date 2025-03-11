defmodule WraftDoc.Assets.Asset do
  @moduledoc """
    The asset model.
  """
  alias __MODULE__
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  @types ~w(layout theme document frame)

  schema "asset" do
    field(:name, :string)
    field(:file, WraftDocWeb.AssetUploader.Type)
    field(:type, :string)
    field(:url, :string)
    field(:expiry_date, :utc_datetime)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name, :type, :organisation_id, :expiry_date, :url])
    |> validate_required([:name, :type, :organisation_id])
    |> validate_inclusion(:type, @types)
  end

  def update_changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name])
    |> cast_attachments(attrs, [:file])
    |> validate_required([:name, :file])
  end

  def update_expiry_date_changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:expiry_date, :url])
    |> validate_required([:expiry_date, :url])
  end

  def file_changeset(asset, attrs \\ %{}) do
    asset
    |> cast_attachments(attrs, [:file])
    |> validate_required([:file])
    |> format_naming()
  end

  # Rename spaces to hyphens in the file name
  defp format_naming(changeset) when changeset.valid? do
    changeset
    |> get_change(:file)
    |> Map.update!(:file_name, &String.replace(&1, ~r/\s+/, "-"))
    |> (&put_change(changeset, :file, &1)).()
  end

  defp format_naming(changeset), do: changeset
end
