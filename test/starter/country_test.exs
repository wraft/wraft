defmodule WraftDoc.CountryTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Account.Country

  @valid_attrs %{country_name: "india", country_code: "65656665", calling_code: "26263"}
  @invalid_attrs %{country_name: "india"}

  test "changeset with valid attributes" do
    changeset = Country.changeset(%Country{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Country.changeset(%Country{}, @invalid_attrs)
    refute changeset.valid?
  end
end
