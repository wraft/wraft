defmodule WraftDoc.Documents.CollectionFormTest do
  use WraftDoc.ModelCase

  @moduledoc """
  Test module
  """

  alias WraftDoc.CollectionForms.CollectionForm

  uuid = Ecto.UUID.bingenerate()
  @create_attrs %{title: "asset one", organisation_id: uuid, creator_id: uuid}
  @invalid_attrs %{title: 23}

  test "changeset with valid data" do
    changeset = CollectionForm.changeset(%CollectionForm{}, @create_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = CollectionForm.changeset(%CollectionForm{}, @invalid_attrs)
    refute changeset.valid?
  end
end
