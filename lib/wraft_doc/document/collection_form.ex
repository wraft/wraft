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

    has_many(:collection_form_fields, CollectionFormField)
    timestamps()
  end

  def changeset(collection_form, attrs \\ %{}) do
    collection_form
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end

  def update_changeset(collection_form, attrs \\ %{}) do
    collection_form
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end
end
