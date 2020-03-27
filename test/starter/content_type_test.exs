defmodule WraftDoc.ContentTypeTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.ContentType

  @valid_attributes %{
    name: "Offer letter",
    description: "A letter issued by Employer to employee in the time of joinig",
    fields: %{name: "string", designation: "string", joining_date: "date", approved_by: "string"},
    prefix: "OFFR",
    organisation_id: 10
  }
  @invalid_attrs %{name: "ofer letter"}
  test "changeset with valid attributes" do
    changeset = ContentType.changeset(%ContentType{}, @valid_attributes)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = ContentType.changeset(%ContentType{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "content type name unique index" do
    organisation = insert(:organisation)
    params = Map.put(@valid_attributes, :organisation_id, organisation.id)

    {:ok, _content_type} = ContentType.changeset(%ContentType{}, params) |> Repo.insert()

    {:error, changeset} = ContentType.changeset(%ContentType{}, params) |> Repo.insert()

    assert "Content type with the same name under your organisation exists.!" in errors_on(
             changeset,
             :name
           )
  end

  test "changeset with valid color format" do
    params_a = Map.put(@valid_attributes, :color, "#FF3323")
    changeset_a = ContentType.changeset(%ContentType{}, params_a)
    assert changeset_a.valid?
    params_b = Map.put(@valid_attributes, :color, "#ff3")
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
