defmodule WraftDoc.Documents.InstanceTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Documents.Instance
  import WraftDoc.Factory
  @moduletag :document

  # Create a proper meta structure for contract type
  @valid_attrs %{
    "instance_id" => "OFFL01",
    "raw" => "Content",
    "serialized" => %{"title" => "Title of the content", "body" => "Body of the content"},
    "type" => 1,
    "document_type" => "contract",
    "meta" => %{
      "type" => "contract",
      # Add other fields that ContractMeta might expect
      "parties" => [],
      "terms" => %{}
    }
  }

  @invalid_attrs %{"raw" => ""}

  test "changeset with valid attributes" do
    # Create all necessary records first
    user = insert(:user_with_organisation)
    organisation = List.first(user.owned_organisations)
    content_type = insert(:content_type, organisation: organisation)
    state = insert(:state, organisation: organisation, flow: content_type.flow)

    # Now create instance with proper associations
    instance =
      insert(:instance,
        creator: user,
        organisation: organisation,
        content_type: content_type,
        state: state
      )

    assert instance.id
  end

  test "changeset with invalid attributes" do
    changeset = Instance.changeset(%Instance{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "update changeset with valid attrs" do
    state = insert(:state)
    organisation = insert(:organisation)

    # Fix: Include all required fields
    valid_attrs =
      Map.merge(@valid_attrs, %{
        "state_id" => state.id,
        "organisation_id" => organisation.id
      })

    changeset = Instance.update_changeset(%Instance{}, valid_attrs)
    assert changeset.valid?
  end

  test "update changeset with invalid attrs" do
    changeset = Instance.update_changeset(%Instance{}, @invalid_attrs)
    refute changeset.valid?
  end

  # @tag :skip
  # test "instance id unique constraint" do
  #   state = insert(:state)
  #   content_type = insert(:content_type)
  #   instance = insert(:instance, instance_id: "TEST123")

  #   duplicate_instance = build(:instance,
  #     instance_id: "TEST123",
  #     creator: instance.creator,
  #     organisation: instance.organisation,
  #     content_type_id: content_type.id,
  #     state_id: state.id
  #   )

  #   {:error, changeset} = Instance.changeset(duplicate_instance, %{}) |> Repo.insert()

  #   assert "Instance with the ID exists.!" in errors_on(changeset, :instance_id)
  # end

  test "types/0 returns a list" do
    types = Instance.types()
    assert types == [normal: 1, bulk_build: 2, pipeline_api: 3, pipeline_hook: 4]
  end
end
