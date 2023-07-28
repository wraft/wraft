defmodule WraftDoc.Forms.Form do
  @moduledoc """
    The form model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @fields [:description, :name, :prefix, :status, :organisation_id, :creator_id]

  schema "form" do
    field(:description, :string)
    field(:name, :string)
    field(:prefix, :string)
    field(:status, Ecto.Enum, values: [:active, :inactive])
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:form_fields, WraftDoc.Forms.FormField)
    has_many(:fields, through: [:form_fields, :field])
    has_many(:form_mappings, WraftDoc.Forms.FormMapping)
    has_many(:pipe_stages, through: [:form_mappings, :pipe_stage])
    has_many(:form_entry, WraftDoc.Forms.FormEntry)
    has_many(:form_pipeline, WraftDoc.Forms.FormPipeline)
    has_many(:pipeline, through: [:form_pipeline, :pipeline])
    timestamps()
  end

  def changeset(%Form{} = form, attrs) do
    form
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> foreign_key_constraint(:creator_id, message: "Please enter a valid user")
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end
end
