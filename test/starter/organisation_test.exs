defmodule WraftDoc.OrganisationTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Enterprise.Organisation}

  @valid_attrs %{
    name: "Company",
    legal_name: "Company Pvt Ltd",
    address: "#541, Gandhinagar 2nd Street",
    name_of_ceo: "John Doe",
    name_of_cto: "John Doe Jr",
    gstin: "n1235kjqw81",
    corporate_id: "F5783NJUG",
    phone: "9090909090",
    email: "hello@comapny.com"
  }

  @invalid_attrs %{name: ""}

  test "changeset with valid attributes" do
    changeset = Organisation.changeset(%Organisation{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Organisation.changeset(%Organisation{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "test organisation name unique constraint" do
    {:ok, _} = Organisation.changeset(%Organisation{}, @valid_attrs) |> Repo.insert()
    {:error, changeset} = Organisation.changeset(%Organisation{}, @valid_attrs) |> Repo.insert()

    assert "Organisation name already taken.! Try another one." in errors_on(
             changeset,
             :legal_name
           )
  end

  test "test GSTIN unique constraint" do
    params = @valid_attrs |> Map.put(:name, "Comapny 2")
    {:ok, _} = Organisation.changeset(%Organisation{}, @valid_attrs) |> Repo.insert()
    {:error, changeset} = Organisation.changeset(%Organisation{}, params) |> Repo.insert()

    assert "GSTIN Already Registered" in errors_on(changeset, :gstin)
  end
end
