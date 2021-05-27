defmodule WraftDoc.Document.ContentTypeTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  @moduletag :document
  alias WraftDoc.Document.ContentType

  @valid_attributes %{
    name: "Offer letter",
    description: "A letter issued by Employer to employee in the time of joinig",
    fields: %{name: "string", designation: "string", joining_date: "date", approved_by: "string"},
    prefix: "OFFR"
  }
  @invalid_attrs %{name: "ofer letter"}
  test "changeset with valid attributes" do
    organisation = insert(:organisation)
    valid_attrs = Map.merge(@valid_attributes, %{organisation_id: organisation.id})
    changeset = ContentType.changeset(%ContentType{}, valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = ContentType.changeset(%ContentType{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "content type name unique index" do
    organisation = insert(:organisation)
    params = Map.put(@valid_attributes, :organisation_id, organisation.id)

    {:ok, _content_type} = %ContentType{} |> ContentType.changeset(params) |> Repo.insert()

    {:error, changeset} = %ContentType{} |> ContentType.changeset(params) |> Repo.insert()

    assert "Content type with the same name under your organisation exists.!" in errors_on(
             changeset,
             :name
           )
  end

  test "changeset with valid color format" do
    organisation = insert(:organisation)
    params_a = Map.merge(@valid_attributes, %{color: "#FF3323", organisation_id: organisation.id})
    changeset_a = ContentType.changeset(%ContentType{}, params_a)
    assert changeset_a.valid?
    params_b = Map.merge(@valid_attributes, %{color: "#ff3", organisation_id: organisation.id})
    changeset_b = ContentType.changeset(%ContentType{}, params_b)
    assert changeset_b.valid?
  end

  test "changeset with invalid color format" do
    params_a = Map.put(@valid_attributes, :color, "#SF3323")
    changeset_a = ContentType.changeset(%ContentType{}, params_a)
    refute changeset_a.valid?
    params_b = Map.put(@valid_attributes, :color, "FF3323")
    changeset_b = ContentType.changeset(%ContentType{}, params_b)
    refute changeset_b.valid?
  end
end
