defmodule WraftDoc.Documents.LayoutAssetTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Layouts.LayoutAsset
  @moduletag :document
  @invalid_attrs %{layout_id: nil, asset_id: nil}
  # TO_DO remove layout assets make it into assets , as per the new revamps
  test "changeset with valid attributes" do
    %{id: l_id} = insert(:layout)
    %{id: a_id} = insert(:asset)
    params = %{layout_id: l_id, asset_id: a_id}
    changeset = LayoutAsset.changeset(%LayoutAsset{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = LayoutAsset.changeset(%LayoutAsset{}, @invalid_attrs)
    refute changeset.valid?
  end

  # FIXME
  # test "test asset-layout unique constraint" do
  #   %{id: l_id} = insert(:layout)
  #   %{id: a_id} = insert(:asset)
  #   params = %{layout_id: l_id, asset_id: a_id}
  #   {:ok, _} = %LayoutAsset{} |> LayoutAsset.changeset(params) |> Repo.insert()
  #   {:error, changeset} = %LayoutAsset{} |> LayoutAsset.changeset(params) |> Repo.insert()
  #   assert "Asset already added.!" in errors_on(changeset, :layout_id)
  # end
end
