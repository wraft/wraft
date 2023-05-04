defmodule WraftDoc.Enterprise.OrganisationTest do
  use WraftDoc.ModelCase
  @moduletag :enterprise

  import WraftDoc.Factory, only: [insert: 1]

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  @valid_attrs %{
    name: "Company",
    legal_name: "Company Pvt Ltd",
    address: "#541, Gandhinagar 2nd Street",
    name_of_ceo: "John Doe",
    name_of_cto: "John Doe Jr",
    gstin: "n1235kjqw81",
    corporate_id: "F5783NJUG",
    phone: "9090909090",
    email: "hello@company.com",
    creator_id: Faker.UUID.v4()
  }

  @valid_attrs_personal %{
    name: "Personal",
    email: "hello@company.com"
  }

  @invalid_attrs %{name: ""}

  describe "changeset/2" do
    # TODO - include tests for name and legal_name constraint
    # TODO - include tests for validate_name
    test "changeset with valid attributes" do
      changeset = Organisation.changeset(%Organisation{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Organisation.changeset(%Organisation{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "checks GSTIN unique constraint" do
      user = insert(:user)
      params = Map.merge(@valid_attrs, %{name: "Company 2", creator_id: user.id})
      params2 = Map.merge(params, %{name: "Company 2"})

      {:ok, _} =
        %Organisation{}
        |> Organisation.changeset(params)
        |> Repo.insert()

      {:error, changeset} =
        %Organisation{}
        |> Organisation.changeset(params2)
        |> Repo.insert()

      assert "GSTIN Already Registered" in errors_on(changeset, :gstin)
    end

    # TODO - check if organisation is not Personal
  end

  describe "personal_organisation_changeset/2" do
    test "changeset with valid attributes" do
      changeset =
        Organisation.personal_organisation_changeset(%Organisation{}, @valid_attrs_personal)

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Organisation.personal_organisation_changeset(%Organisation{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "returns error changeset when all the required fields are missing" do
      changeset = Organisation.personal_organisation_changeset(%Organisation{}, %{})
      assert "can't be blank" in errors_on(changeset, :name)
      assert "can't be blank" in errors_on(changeset, :email)
    end

    test "returns error on incorrect personal organisation name" do
      params = Map.put(@valid_attrs_personal, :name, "Not Personal")
      changeset = Organisation.personal_organisation_changeset(%Organisation{}, params)
      assert "has invalid format" == Enum.at(errors_on(changeset, :name), 0)
    end
  end

  describe "logo_changeset/1" do
    # Test case with valid logo file
    # Test case with invalid file
    # Test case with no logo
  end
end
