defmodule WraftDoc.Account.ProfileTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Account.Profile
  import WraftDoc.Factory

  @valid_attrs %{
    name: "under world",
    gender: "male",
    user_id: 1
  }

  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Profile.changeset(%Profile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Profile.changeset(%Profile{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset with a local file path image url attribute with upload files" do
    profile = insert(:profile)

    local_file_path = File.cwd!() <> "/test/fixtures/avatar600x600.png"

    attrs = Map.put(@valid_attrs, :profile_pic, local_file_path)

    changeset = Profile.changeset(profile, attrs)

    assert changeset.valid?
    refute Map.has_key?(changeset.changes, :profile_pic)
  end

  test "changeset with a file uploader struct" do
    profile = insert(:profile)

    profile_pic = %Plug.Upload{
      content_type: "image/png",
      path: File.cwd!() <> "/test/helper/images.png",
      filename: "images.png"
    }

    attrs = Map.put(@valid_attrs, :profile_pic, profile_pic)

    changeset = Profile.changeset(profile, attrs)

    assert changeset.valid?
    assert Map.has_key?(changeset.changes, :profile_pic)
  end
end
