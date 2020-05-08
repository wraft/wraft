defmodule WraftDoc.Document.Pipeline.StageTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.Stage
  import WraftDoc.Factory
  import Ecto

  test "pipeline stage unique constraint" do
    c_type = insert(:content_type)
    pipeline = insert(:pipeline)
    stage_struct = pipeline |> build_assoc(:stages, content_type: c_type)

    {:ok, _stage} = Stage.changeset(stage_struct, %{}) |> Repo.insert()
    {:error, changeset} = Stage.changeset(stage_struct, %{}) |> Repo.insert()

    assert "Already added.!" in errors_on(changeset, :content_type_id)
  end
end
