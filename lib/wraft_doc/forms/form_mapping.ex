defmodule WraftDoc.Forms.FormMapping do
  @moduledoc """
  form mapping  model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @form_mapping_fields [:form_id, :pipe_stage_id]
  @mapping_fields [:source, :destination]

  schema "form_mapping" do
    embeds_many :mapping, Mapping, on_replace: :delete do
      field(:source, :map)
      field(:destination, :map)
    end

    belongs_to(:pipe_stage, WraftDoc.Document.Pipeline.Stage)
    belongs_to(:form, WraftDoc.Forms.Form)

    timestamps()
  end

  def changeset(%FormMapping{} = form_mapping, params \\ %{}) do
    form_mapping
    |> cast(params, @form_mapping_fields)
    |> cast_embed(:mapping, required: true, with: &map_changeset/2)
    |> validate_required(@form_mapping_fields)
    |> foreign_key_constraint(:form_id, message: "Please enter an existing form")
    |> foreign_key_constraint(:pipe_stage_id, message: "Please enter an existing pipe stage")
    |> unique_constraint(@form_mapping_fields,
      name: :form_pipe_stage_unique_index,
      message: "already exist"
    )
  end

  def update_changeset(%FormMapping{} = form_mapping, params \\ %{}) do
    form_mapping
    |> cast(params, @form_mapping_fields)
    |> cast_embed(:mapping, required: false, with: &update_map_changeset/2)
    |> foreign_key_constraint(:form_id, message: "Please enter an existing form")
    |> foreign_key_constraint(:pipe_stage_id, message: "Please enter an existing pipe stage")
    |> unique_constraint(@form_mapping_fields,
      name: :form_pipe_stage_unique_index,
      message: "already exist"
    )
  end

  def update_map_changeset(%FormMapping.Mapping{} = mapping, attrs \\ %{}) do
    cast(mapping, attrs, @mapping_fields)
  end

  def map_changeset(%FormMapping.Mapping{} = mapping, attrs \\ %{}) do
    mapping
    |> cast(attrs, @mapping_fields)
    |> validate_required(@mapping_fields)
  end
end
