defmodule WraftDoc.Document.CollectionForm do
  @moduledoc """
  Generic collection form
  Example :-  Google form
  """

  use WraftDoc.Schema
  alias WraftDoc.Document.CollectionFormField

  # defimpl Spur.Trackable, for: CollectionForm do
  #   def actor(collection_form), do: "#{collection_form.creator_id}"
  #   def object(collection_form), do: "CollectionForm:#{collection_form.id}"
  #   def target(_chore), do: nil

  #   def audience(%{organisation_id: id}) do
  #     from(u in User, where: u.organisation_id == ^id)
  #   end
  # end

  schema "collection_form" do
    field(:title, :string, null: false)
    field(:description, :string)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)
    has_many(:fields, CollectionFormField)
    timestamps()
  end

  def changeset(collection_form, attrs \\ %{}) do
    collection_form
    |> cast(attrs, [:title, :description, :organisation_id, :creator_id])
    |> validate_required([:title, :organisation_id, :creator_id])
    |> cast_assoc(:fields, with: &CollectionFormField.changeset/2)
  end

  def update_changeset(collection_form, attrs \\ %{}) do
    collection_form
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
    |> cast_assoc(:fields, with: &CollectionFormField.update_changeset/2)
  end
end