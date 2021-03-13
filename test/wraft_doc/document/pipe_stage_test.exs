defmodule WraftDoc.Document.Pipeline.StageTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.Stage
  import WraftDoc.Factory
  import Ecto

  test "changeset with valid attrs" do
    %{id: u_id} = insert(:user)
    %{id: c_id} = insert(:content_type)
    pipeline = insert(:pipeline)
    %{id: d_id} = insert(:data_template)
    %{id: s_id} = insert(:state)

    stage_struct =
      build_assoc(pipeline, :stages,
        content_type_id: c_id,
        data_template_id: d_id,
        state_id: s_id,
        creator_id: u_id
      )

    changeset = Stage.changeset(stage_struct, %{})

    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    pipeline = insert(:pipeline)
    stage_struct = build_assoc(pipeline, :stages, content_type_id: "")
    changeset = Stage.changeset(stage_struct, %{})

    refute changeset.valid?
  end

  test "pipeline stage unique constraint" do
    %{id: u_id} = insert(:user)
    %{id: c_id} = insert(:content_type)
    pipeline = insert(:pipeline)
    %{id: d_id} = insert(:data_template)
    %{id: s_id} = insert(:state)

    stage_struct =
      build_assoc(pipeline, :stages,
        content_type_id: c_id,
        data_template_id: d_id,
        state_id: s_id,
        creator_id: u_id
      )

    {:ok, _stage} = stage_struct |> Stage.changeset(%{}) |> Repo.insert()
    {:error, changeset} = stage_struct |> Stage.changeset(%{}) |> Repo.insert()

    assert "Already added.!" in errors_on(changeset, :content_type_id)
  end

  test "update changeset with valid attrs" do
    stage = insert(:pipe_stage)
    %{id: c_id} = insert(:content_type)
    %{id: d_id} = insert(:data_template)
    %{id: s_id} = insert(:state)

    changeset =
      Stage.update_changeset(stage, %{
        content_type_id: c_id,
        data_template_id: d_id,
        state_id: s_id
      })

    assert changeset.valid?
  end

  test "update changeset with invalid attrs" do
    stage = insert(:pipe_stage)
    changeset = Stage.update_changeset(stage, %{content_type_id: ""})
    refute changeset.valid?
  end
end
