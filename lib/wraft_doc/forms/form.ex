defmodule WraftDoc.Forms.Form do
  @moduledoc """
    The form model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @fields [:description, :name, :prefix, :status, :organisation_id, :creator_id]
  @statuses [:active, :inactive]

  schema "form" do
    field(:description, :string)
    field(:name, :string)
    field(:prefix, :string)
    field(:status, Ecto.Enum, values: @statuses)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:form_fields, WraftDoc.Forms.FormField)
    has_many(:fields, through: [:form_fields, :field])
    has_many(:form_mappings, WraftDoc.Forms.FormMapping)
    has_many(:pipe_stages, through: [:form_mappings, :pipe_stage])
    has_many(:form_entries, WraftDoc.Forms.FormEntry)
    has_many(:form_pipelines, WraftDoc.Forms.FormPipeline)
    has_many(:pipelines, through: [:form_pipelines, :pipeline])
    timestamps()
  end

  def changeset(%Form{} = form, attrs) do
    form
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:prefix,
      message: "Form with the same prefix exists.!",
      name: :form_prefix_unique_index
    )
    |> foreign_key_constraint(:creator_id, message: "Please enter a valid user")
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end

  def update_changeset(%Form{} = form, attrs) do
    form
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end
end
