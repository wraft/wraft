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
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias WraftDoc.{Account.User, Document.ContentType}
  import Ecto.Query
  @derive {Jason.Encoder, only: [:instance_id]}
  def types, do: [normal: 1, bulk_build: 2, pipeline_api: 3, pipeline_hook: 4]

  defimpl Spur.Trackable, for: Instance do
    def actor(instance), do: "#{instance.creator_id}"
    def object(instance), do: "Instance:#{instance.id}"
    def target(_chore), do: nil

    def audience(%{content_type_id: id}) do
      from(u in User,
        join: ct in ContentType,
        where: ct.id == ^id,
        where: u.organisation_id == ct.organisation_id
      )
    end
  end

  schema "content" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:instance_id, :string, null: false)
    field(:raw, :string)
    field(:serialized, :map, default: %{})
    field(:type, :integer)
    field(:build, :string, virtual: true)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:vendor, WraftDoc.Enterprise.Vendor)

    has_many(:build_histories, WraftDoc.Document.Instance.History, foreign_key: :content_id)
    has_many(:versions, WraftDoc.Document.Instance.Version, foreign_key: :content_id)
    has_many(:approval_systems, WraftDoc.Enterprise.ApprovalSystem, foreign_key: :instance_id)
    timestamps()
  end

  def changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [
      :instance_id,
      :raw,
      :serialized,
      :content_type_id,
      :type,
      :creator_id,
      :vendor_id
    ])
    |> validate_required([:instance_id, :raw, :serialized, :type, :content_type_id])
    |> unique_constraint(:instance_id,
      message: "Instance with the ID exists.!",
      name: :content_organisation_unique_index
    )
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
    |> cast(attrs, [:state_id])
    |> validate_required([:state_id])
  end
end
