defmodule WraftDoc.Enterprise.OrganisationTest do
  use WraftDoc.ModelCase
  @moduletag :enterprise
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
    email: "hello@company.com"
  }

  @valid_attrs_personal %{
    name: "Personal",
    email: "hello@company.com"
  }

  @invalid_attrs %{name: ""}

  describe "changeset/2" do
    test "changeset with valid attributes" do
      changeset = Organisation.changeset(%Organisation{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Organisation.changeset(%Organisation{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "checks organisation name unique constraint" do
      {:ok, _} = %Organisation{} |> Organisation.changeset(@valid_attrs) |> Repo.insert()

      {:error, changeset} =
        %Organisation{} |> Organisation.changeset(@valid_attrs) |> Repo.insert()

      assert "Organisation Already Registered." in errors_on(
               changeset,
               :legal_name
             )
    end

    test "checks GSTIN unique constraint" do
      params = Map.put(@valid_attrs, :name, "Company 2")
      {:ok, _} = %Organisation{} |> Organisation.changeset(@valid_attrs) |> Repo.insert()
      {:error, changeset} = %Organisation{} |> Organisation.changeset(params) |> Repo.insert()

      assert "GSTIN Already Registered" in errors_on(changeset, :gstin)
    end
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
end
