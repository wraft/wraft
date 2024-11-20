defmodule WraftDoc.Document.Instance do
  @moduledoc """
    The model for contents every documents build is based on datas on instance
    ## Fields
    * Instance id - an unique id to reffer as a document number in organisation
    * Raw - The raw content of the instance
    * Serialized - the map contains the field values
    * Type - Type of the document generation  [normal: 1, bulk_build: 2, pipeline_api: 3, pipeline_hook: 4]
    * Build -
    * Creator id - Creator of the document
    * Content type id - Id of content type
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.EctoType.DocumentMetaType

  def types, do: [normal: 1, bulk_build: 2, pipeline_api: 3, pipeline_hook: 4]

  schema "content" do
    field(:instance_id, :string)
    field(:raw, :string)
    field(:serialized, :map, default: %{})
    field(:document_type, :string, virtual: true)
    field(:meta, DocumentMetaType)
    field(:type, :integer)
    field(:build, :string, virtual: true)
    field(:next_state, :string, virtual: true)
    field(:previous_state, :string, virtual: true)
    field(:editable, :boolean, default: true)
    field(:allowed_users, {:array, :string}, default: [])
    field(:approval_status, :boolean, default: false)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:vendor, WraftDoc.Enterprise.Vendor)
    has_many(:content_collab, WraftDoc.Document.ContentCollab, foreign_key: :content_id)
    has_many(:instance_approval_systems, WraftDoc.Document.InstanceApprovalSystem)
    has_many(:build_histories, WraftDoc.Document.Instance.History, foreign_key: :content_id)
    has_many(:versions, WraftDoc.Document.Instance.Version, foreign_key: :content_id)

    timestamps()
  end

  def changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [
      :instance_id,
      :raw,
      :document_type,
      :serialized,
      :content_type_id,
      :type,
      :creator_id,
      :vendor_id,
      :allowed_users
    ])
    |> validate_required([
      :instance_id,
      :raw,
      :document_type,
      :serialized,
      :type,
      :content_type_id
    ])
    |> DocumentMetaType.cast_meta(attrs)
    |> unique_constraint(:instance_id,
      message: "Instance with the ID exists.!",
      name: :content_organisation_unique_index
    )
  end

  def meta_changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:meta])
    |> validate_required([:meta])
    |> DocumentMetaType.cast_meta(attrs)
  end

  def update_changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:instance_id, :raw, :serialized])
    |> validate_required([:instance_id, :raw, :serialized])
    |> unique_constraint(:instance_id,
      message: "Instance with the ID exists.!",
      name: :content_organisation_unique_index
    )
  end

  def update_state_changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:state_id, :allowed_users, :approval_status])
    |> validate_required([:state_id])
  end

  def lock_modify_changeset(instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:editable])
    |> validate_required([:editable])
  end
end
