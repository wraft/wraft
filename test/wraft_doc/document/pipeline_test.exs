defmodule WraftDoc.Document.PipelineTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Official Letter",
    api_route: "newclient.example.crm.com"
  }

  test "changeset with valid attrs" do
    %{id: id} = insert(:organisation)
    params = @valid_attrs |> Map.put(:organisation_id, id)
    changeset = Pipeline.changeset(%Pipeline{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Pipeline.changeset(%Pipeline{}, %{})
    refute changeset.valid?
  end

  test "pipeline name unique constraint" do
    organisation = insert(:organisation)
    pipeline = insert(:pipeline, organisation: organisation)
    params = @valid_attrs |> Map.put(:organisation_id, organisation.id)
    {:ok, _pipeline} = Pipeline.changeset(%Pipeline{}, params) |> Repo.insert()
    {:error, changeset} = Pipeline.changeset(%Pipeline{}, params) |> Repo.insert()

    assert "Pipeline with the same name already exists.!" in errors_on(changeset, :name)
  end
end
