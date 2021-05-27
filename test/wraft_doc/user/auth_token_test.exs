defmodule WraftDoc.Account.AuthTokenTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Account.AuthToken
  @moduletag :account
  @valid_attrs %{
    value: "token value",
    token_type: "token type",
    expiry_datetime: Timex.now()
  }

  @invalid_attrs %{value: ""}

  test "changeset with valid attributes" do
    %{id: id} = insert(:user)
    params = Map.put(@valid_attrs, :user_id, id)
    changeset = AuthToken.changeset(%AuthToken{}, params)
    changeset2 = AuthToken.verification_changeset(%AuthToken{}, params)
    assert changeset.valid?
    assert changeset2.valid?
  end

  test "changeset with invalid attributes" do
    changeset = AuthToken.changeset(%AuthToken{}, @invalid_attrs)
    changeset2 = AuthToken.verification_changeset(%AuthToken{}, @invalid_attrs)
    refute changeset.valid?
    refute(changeset2.valid?)
  end
end
