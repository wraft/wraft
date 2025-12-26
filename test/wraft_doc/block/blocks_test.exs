defmodule WraftDoc.Blocks.BlockTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.BlockTemplates
  alias WraftDoc.BlockTemplates.BlockTemplate

  alias WraftDoc.Repo
  setup :verify_on_exit!

  describe "block_template_bulk_insert/3" do
    test "test bulk block template creation with valid data" do
      user = insert(:user_with_organisation)
      mapping = %{"Body" => "body", "Serialized" => "serialized", "Title" => "title"}
      path = "test/helper/block_template_source.csv"

      count_before =
        BlockTemplate
        |> Repo.all()
        |> length()

      block_templates =
        user
        |> BlockTemplates.block_template_bulk_insert(mapping, path)
        |> Enum.map(fn x -> x.title end)
        |> List.to_string()

      assert count_before + 3 ==
               BlockTemplate
               |> Repo.all()
               |> length()

      assert block_templates =~ "B Temp1"
      assert block_templates =~ "B Temp2"
      assert block_templates =~ "B Temp3"
    end

    test "test doesn not do bulk block template creation with invalid data" do
      count_before =
        BlockTemplate
        |> Repo.all()
        |> length()

      response = BlockTemplates.block_template_bulk_insert(nil, nil, nil)

      assert count_before ==
               BlockTemplate
               |> Repo.all()
               |> length()

      assert response == {:error, :not_found}
    end
  end

  describe "create block_template" do
    test "create_block_template/2, test creates block template with valid attrs" do
      user = insert(:user_with_organisation)

      params = %{
        title: "Introduction",
        body: "Hi [employee], we welcome you to our [company], [address]",
        serialized: "Hi [employee], we welcome you to our family"
      }

      count_before =
        BlockTemplate
        |> Repo.all()
        |> length()

      block_template = BlockTemplates.create_block_template(user, params)

      assert count_before + 1 ==
               BlockTemplate
               |> Repo.all()
               |> length()

      assert block_template.title == "Introduction"
      assert block_template.body == "Hi [employee], we welcome you to our [company], [address]"
      assert block_template.serialized == "Hi [employee], we welcome you to our family"
    end

    test "create_block_template/2, test does not create block template with invalid attrs" do
      user = insert(:user_with_organisation)
      {:error, changeset} = BlockTemplates.create_block_template(user, %{})

      assert %{
               title: ["can't be blank"],
               serialized: ["can't be blank"],
               body: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "get block_template" do
    test "get_block_template/2, Create a block template" do
      user = insert(:user_with_organisation)
      block_template = insert(:block_template, organisation: List.first(user.owned_organisations))
      get_block_template = BlockTemplates.get_block_template(block_template.id, user)

      assert block_template.id == get_block_template.id
      assert block_template.organisation_id == get_block_template.organisation_id
    end
  end

  describe "update_block_template/2" do
    test "updates block template with valid attrs" do
      block_template = insert(:block_template)
      params = %{"title" => "new title", "body" => "new body"}
      update_btemplate = BlockTemplates.update_block_template(block_template, params)

      assert update_btemplate.title =~ "new title"
      assert update_btemplate.body =~ "new body"
    end

    test "returns error with invalid attrs" do
      block_template = insert(:block_template)
      params = %{"title" => nil, "body" => "new body"}
      {:error, changeset} = BlockTemplates.update_block_template(block_template, params)

      assert %{title: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "delete_block_template" do
    test "deletes block_template with valid attrs" do
      block_template = insert(:block_template)
      {:ok, _delete_btemp} = BlockTemplates.delete_block_template(block_template)
      refute Repo.get(BlockTemplate, block_template.id)
    end

    test "returns error with invalid attrs" do
      assert {:error, :fake} = BlockTemplates.delete_block_template(nil)
    end
  end

  describe "get index of block_template" do
    test "index_block_template/2, Index of a block template by organisation" do
      user = insert(:user_with_organisation)

      b_temp =
        :block_template
        |> insert()
        |> Map.from_struct()

      bt_index = BlockTemplates.index_block_template(user, b_temp)

      assert Map.has_key?(bt_index, :entries)
      assert Map.has_key?(bt_index, :total_entries)
      assert is_number(bt_index.total_pages)
    end
  end
end
