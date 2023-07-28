defmodule WraftDoc.Forms.FormPipelineTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :forms
  alias WraftDoc.Forms.FormPipeline
  import WraftDoc.Factory

  @invalid_attrs %{form_id: nil, pipeline_id: nil}

  describe "changeset/2" do
    test "changeset with valid attributes" do
      form = insert(:form)
      pipeline = insert(:pipeline)

      changeset =
        FormPipeline.changeset(%FormPipeline{}, %{
          form_id: form.id,
          pipeline_id: pipeline.id
        })

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = FormPipeline.changeset(%FormPipeline{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "foreign key constraint on form_id" do
      pipeline = insert(:pipeline)

      params = %{
        form_id: Ecto.UUID.generate(),
        pipeline_id: pipeline.id
      }

      {:error, changeset} = %FormPipeline{} |> FormPipeline.changeset(params) |> Repo.insert()

      assert "Please enter an existing form" in errors_on(changeset, :form_id)
    end

    test "foreign key constraint on pipeline_id" do
      form = insert(:form)

      params = %{
        form_id: form.id,
        pipeline_id: Ecto.UUID.generate()
      }

      {:error, changeset} = %FormPipeline{} |> FormPipeline.changeset(params) |> Repo.insert()

      assert "Please enter an existing pipeline" in errors_on(changeset, :pipeline_id)
    end

    test "form pipeline unique constraint" do
      form = insert(:form)
      pipeline = insert(:pipeline)

      params = %{
        form_id: form.id,
        pipeline_id: pipeline.id
      }

      {:ok, _} = %FormPipeline{} |> FormPipeline.changeset(params) |> Repo.insert()

      {:error, changeset} = %FormPipeline{} |> FormPipeline.changeset(params) |> Repo.insert()

      assert "already exist" in errors_on(
               changeset,
               :form_id
             )
    end
  end
end
