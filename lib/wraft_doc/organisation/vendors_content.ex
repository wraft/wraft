defmodule WraftDoc.Enterprise.VendorsContent do
  @moduledoc """
  Schema for the many-to-many relationship between Vendors and Contents (Documents).
  """
  use WraftDoc.Schema

  @fields [:vendor_id, :content_id]

  schema "vendors_contents" do
    belongs_to(:vendor, WraftDoc.Enterprise.Vendor)
    belongs_to(:content, WraftDoc.Documents.Instance)

    timestamps()
  end

  def changeset(%__MODULE__{} = vendors_contents, params \\ %{}) do
    vendors_contents
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> unique_constraint(@fields, message: "already exist")
    |> foreign_key_constraint(:vendor_id, message: "Please enter a valid vendor")
    |> foreign_key_constraint(:contents_id, message: "Please enter a valid content")
  end
end
