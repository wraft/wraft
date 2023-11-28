defmodule WraftDoc.AuthTokens.AuthTokenTest do
  use WraftDoc.ModelCase

  import WraftDoc.Factory

  alias WraftDoc.AuthTokens.AuthToken

  @moduletag :account

  @valid_attrs %{
    value: "token value",
    token_type: :password_verify,
    expiry_datetime: Timex.now()
  }

  @invalid_attrs %{value: ""}

  test "changeset with valid attributes" do
    %{id: id} = insert(:user)
    params = Map.put(@valid_attrs, :user_id, id)
    changeset = AuthToken.changeset(%AuthToken{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = AuthToken.changeset(%AuthToken{}, @invalid_attrs)
    refute changeset.valid?
  end
end
