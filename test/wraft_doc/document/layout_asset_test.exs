defmodule WraftDoc.Document.LayoutAssetTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Document.LayoutAsset, Repo}

  @invalid_attrs %{layout_id: nil, asset_id: nil}
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

  test "test asset-layout unique constraint" do
    %{id: l_id} = insert(:layout)
    %{id: a_id} = insert(:asset)
    params = %{layout_id: l_id, asset_id: a_id}
    {:ok, _} = %LayoutAsset{} |> LayoutAsset.changeset(params) |> Repo.insert()
    {:error, changeset} = %LayoutAsset{} |> LayoutAsset.changeset(params) |> Repo.insert()
    assert "Asset already added.!" in errors_on(changeset, :layout_id)
  end
end
