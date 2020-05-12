defmodule WraftDoc.Document.Pipeline.StageTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.Stage
  import WraftDoc.Factory
  import Ecto

  test "pipeline stage unique constraint" do
    %{id: u_id} = insert(:user)
    %{id: c_id} = insert(:content_type)
    pipeline = insert(:pipeline)
    %{id: d_id} = insert(:data_template)
    %{id: s_id} = insert(:state)

    stage_struct =
      pipeline
      |> build_assoc(:stages,
        content_type_id: c_id,
        data_template_id: d_id,
        state_id: s_id,
        creator_id: u_id
      )

    {:ok, _stage} = Stage.changeset(stage_struct, %{}) |> Repo.insert()
    {:error, changeset} = Stage.changeset(stage_struct, %{}) |> Repo.insert()

    assert "Already added.!" in errors_on(changeset, :content_type_id)
  end
end
