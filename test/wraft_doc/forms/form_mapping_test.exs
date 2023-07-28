defmodule WraftDoc.Forms.FormMappingTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :forms
  alias WraftDoc.Forms.FormMapping
  alias WraftDoc.Forms.FormMapping.Mapping
  import WraftDoc.Factory

  @invalid_attrs %{form_id: nil, field_id: nil}

  @mapping [
    %{
      content_type_field_id: Ecto.UUID.generate(),
      form_field_id: Ecto.UUID.generate()
    },
    %{
      content_type_field_id: Ecto.UUID.generate(),
      form_field_id: Ecto.UUID.generate()
    }
  ]

  describe "changeset/2" do
    test "changeset with valid attributes" do
      pipe_stage = insert(:pipe_stage)
      form = insert(:form)

      changeset =
        FormMapping.changeset(%FormMapping{}, %{
          mapping: @mapping,
          pipe_stage_id: pipe_stage.id,
          form_id: form.id
        })

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = FormMapping.changeset(%FormMapping{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "foreign key constraint on form_id" do
      pipe_stage = insert(:pipe_stage)

      params = %{
        mapping: @mapping,
        pipe_stage_id: pipe_stage.id,
        form_id: Ecto.UUID.generate()
      }

      {:error, changeset} = %FormMapping{} |> FormMapping.changeset(params) |> Repo.insert()

      assert "Please enter an existing form" in errors_on(changeset, :form_id)
    end

    test "foreign key constraint on pipe_stage_id" do
      form = insert(:form)

      params = %{
        mapping: @mapping,
        pipe_stage_id: Ecto.UUID.generate(),
        form_id: form.id
      }

      {:error, changeset} = %FormMapping{} |> FormMapping.changeset(params) |> Repo.insert()

      assert "Please enter an existing pipe stage" in errors_on(changeset, :pipe_stage_id)
    end

    test "form pipe stage unique constraint" do
      form = insert(:form)
      pipe_stage = insert(:pipe_stage)

      params = %{
        mapping: @mapping,
        pipe_stage_id: pipe_stage.id,
        form_id: form.id
      }

      {:ok, _} = %FormMapping{} |> FormMapping.changeset(params) |> Repo.insert()

      {:error, changeset} = %FormMapping{} |> FormMapping.changeset(params) |> Repo.insert()

      assert "already exist" in errors_on(
               changeset,
               :form_id
             )
    end
  end

  describe "map_changeset/2" do
    test "changeset with valid attributes" do
      content_type_field = insert(:content_type_field)
      form_field = insert(:form_field)

      changeset =
        FormMapping.map_changeset(%Mapping{}, %{
          content_type_field_id: content_type_field.id,
          form_field_id: form_field.id
        })

      assert changeset.valid?
    end

    test "changeset with missing attributes" do
      changeset = FormMapping.map_changeset(%Mapping{}, %{})

      refute changeset.valid?
    end
  end
end
