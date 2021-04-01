defmodule WraftDoc.Organisation.OrganisationRoleTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Organisation.OrganisationRole

  @valid_attrs %{
    organisation_id: "1234567",
    role_id: "12345"
  }
  @invalid_attrs %{}

  test "changeset with valid attrs" do
    changeset = OrganisationRole.changeset(%OrganisationRole{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = OrganisationRole.changeset(%OrganisationRole{}, @invalid_attrs)
    refute changeset.valid?
  end
end
