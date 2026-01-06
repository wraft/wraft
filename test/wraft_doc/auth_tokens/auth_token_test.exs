defmodule WraftDoc.AuthTokens.AuthTokenTest do
  # DO_ME
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

  # Helper function for changeset errors
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

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

  test "changeset requires token_type" do
    params = %{value: "value"}
    changeset = AuthToken.changeset(%AuthToken{}, params)
    refute changeset.valid?
    assert %{token_type: ["can't be blank"]} == errors_on(changeset)
  end

  test "changeset accepts all valid token types" do
    %{id: id} = insert(:user)

    token_types = [
      :password_verify,
      :invite,
      :email_verify,
      :set_password,
      :delete_organisation,
      :document_invite,
      :signer_invite
    ]

    Enum.each(token_types, fn type ->
      params = %{value: "value", token_type: type, user_id: id}
      changeset = AuthToken.changeset(%AuthToken{}, params)
      assert changeset.valid?, "Failed for token_type: #{type}"
    end)
  end

  test "changeset rejects invalid token_type" do
    %{id: id} = insert(:user)
    params = %{value: "value", token_type: :invalid, user_id: id}
    changeset = AuthToken.changeset(%AuthToken{}, params)
    refute changeset.valid?
    assert %{token_type: ["is invalid"]} == errors_on(changeset)
  end

  test "changeset allows optional expiry_datetime" do
    %{id: id} = insert(:user)

    params = %{
      value: "value",
      token_type: :password_verify,
      user_id: id,
      expiry_datetime: Timex.now()
    }

    changeset = AuthToken.changeset(%AuthToken{}, params)
    assert changeset.valid?
  end
end
