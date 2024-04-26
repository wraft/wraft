defmodule WraftDoc.Document.PipelineTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline
  import WraftDoc.Factory
  @moduletag :document
  @valid_attrs %{
    name: "Official Letter",
    source: "WraftForms",
    source_id: "1232148nb3478",
    api_route: "newclient.example.crm.com"
  }

  @update_valid_attrs %{name: ""}

  test "changeset with valid attrs" do
    %{id: id} = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, id)
    changeset = Pipeline.changeset(%Pipeline{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Pipeline.changeset(%Pipeline{}, %{})
    refute changeset.valid?
  end

  test "update changeset with valid attrs" do
    pipeline = insert(:pipeline)
    changeset = Pipeline.changeset(pipeline, @valid_attrs)
    assert changeset.valid?
  end

  test "update changeset with invalid attrs" do
    pipeline = insert(:pipeline)
    changeset = Pipeline.changeset(pipeline, @update_valid_attrs)
    refute changeset.valid?
  end

  test "pipeline name unique constraint" do
    organisation = insert(:organisation)
    insert(:pipeline, organisation: organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation.id)
    {:ok, _pipeline} = %Pipeline{} |> Pipeline.changeset(params) |> Repo.insert()
    {:error, changeset} = %Pipeline{} |> Pipeline.changeset(params) |> Repo.insert()

    assert "Pipeline with the same name already exists.!" in errors_on(changeset, :name)
  end

  # TODO tests for update_changeset
  # TODO tests for unique constraint in update_changeset
end
