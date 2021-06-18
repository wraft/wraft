defmodule WraftDoc.Document.CollectionFormTest do
  use WraftDoc.ModelCase

  @moduledoc """
  Test module
  """

  alias WraftDoc.Document.CollectionForm

  @create_attrs %{title: "asset one"}
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
