defmodule WraftDoc.DocumentTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.Account.Role
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Blocks.Block
  alias WraftDoc.BlockTemplates
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.CollectionForms.CollectionForm
  alias WraftDoc.CollectionForms.CollectionFormField
  alias WraftDoc.Comments
  alias WraftDoc.Comments.Comment
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Counter
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Instance.History
  alias WraftDoc.Documents.Instance.Version
  alias WraftDoc.Documents.InstanceApprovalSystem
  alias WraftDoc.Fields
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.Stages.Stage
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset
  alias WraftDoc.Validations.Validation
  setup :verify_on_exit!

  @valid_layout_attrs %{
    "name" => "layout name",
    "description" => "layout description",
    "width" => 25.0,
    "height" => 44.0,
    "unit" => "cm",
    "slug" => "layout slug"
    # "engine_id" => "00f47af7-6db5-4b93-bafb-99d453929aea"
  }
  @valid_instance_attrs %{
    "instance_id" => "OFFR0001",
    "raw" => "instance raw",
    "serialized" => %{
      "body" => "body of the content",
      "title" => "title of the content"
    },
    "type" => 1,
    "state_id" => "a041a482-202c-4c53-99f3-79a8dab252d5"
  }
  @valid_content_type_attrs %{
    "name" => "content_type name",
    "description" => "content_type description",
    "color" => "#fff",
    "prefix" => "OFFRE"
  }

  @valid_theme_attrs %{
    "name" => "theme name",
    "font" => "theme font",
    "typescale" => %{
      "heading1" => 22,
      "heading2" => 16,
      "paragraph" => 12
    },
    "preview_file" => %Plug.Upload{
      filename: "invoice.pdf",
      path: "test/helper/invoice.pdf",
      content_type: "application/pdf"
    }
  }

  @valid_data_template_attrs %{
    "title" => "data_template title",
    "title_template" => "data_template title_template",
    "data" => "data_template data",
    "serialized" => %{
      "company" => "Apple"
    }
  }
  @invalid_data_template_attrs %{title: nil, title_template: nil, data: nil}
  @valid_asset_attrs %{
    "name" => "asset name",
    "type" => "layout",
    "file" => %Plug.Upload{
      content_type: "application/pdf",
      filename: "invoice.pdf",
      path: "test/helper/invoice.pdf"
    }
  }

  @valid_comment_attrs %{
    "comment" => "comment comment",
    "is_parent" => true,
    "master" => "instance",
    "master_id" => "0s3df0sd03f3s03d0f3",
    "organisation_id" => 12
  }
  @invalid_comment_attrs %{
    "comment" => nil,
    "is_parent" => nil,
    "master" => nil,
    "master_id" => nil,
    "organisation_id" => nil
  }
  @invalid_instance_attrs %{raw: nil}
  @invalid_attrs %{}

  @data [
    %{"label" => "January", "value" => 10},
    %{"label" => "February", "value" => 20},
    %{"label" => "March", "value" => 5},
    %{"label" => "April", "value" => 60},
    %{"label" => "May", "value" => 80},
    %{"label" => "June", "value" => 70},
    %{"label" => "Julay", "value" => 90}
  ]
  @update_valid_attrs %{
    "btype" => "gantt",
    "file_url" => "/usr/local/hoem/filex.svg",
    "api_route" => "http://localhost:4000",
    "dataset" => %{
      "backgroundColor" => "transparent",
      "data" => @data,
      "format" => "svg",
      "height" => 512,
      "type" => "pie",
      "width" => 512
    },
    "endpoint" => "blocks_api",
    "name" => "Farming"
  }

  describe "create_instance/4" do
    test "create instance on valid attributes and updates count of instances at counter" do
      user = insert(:user)
      content_type = insert(:content_type)
      flow = content_type.flow
      state = insert(:state, flow: flow)
      state_id = state.id

      params = %{
        "instance_id" => "OFFR0001",
        "raw" => "instance raw",
        "serialized" => %{
          "body" => "body of the content",
          "title" => "title of the content"
        },
        "type" => 1,
        "state_id" => "a041a482-202c-4c53-99f3-79a8dab252d5"
      }

      params = Map.merge(params, %{"state_id" => state_id})

      counter_count =
        Counter
        |> Repo.all()
        |> length()

      count_before =
        Instance
        |> Repo.all()
        |> length()

      instance = Documents.create_instance(user, content_type, state, params)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      counter_count_after =
        Counter
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert counter_count + 1 == counter_count_after
      assert instance.raw == @valid_instance_attrs["raw"]
      assert instance.serialized == @valid_instance_attrs["serialized"]
    end

    test "does not create instance, on invalid attrs" do
      user = insert(:user)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      content_type = insert(:content_type)
      state = insert(:state, flow: content_type.flow)

      {:error, changeset} = Documents.create_instance(user, content_type, state, @invalid_attrs)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               raw: ["can't be blank"],
               type: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "create_instance/3" do
    test "create an instance on valid attributes and updates count of instances at counter" do
      user = insert(:user)
      content_type = insert(:content_type)
      flow = content_type.flow
      state = insert(:state, flow: flow)
      state_id = state.id

      params = %{
        "instance_id" => "OFFR0001",
        "raw" => "instance raw",
        "serialized" => %{
          "body" => "body of the content",
          "title" => "title of the content"
        },
        "type" => 1,
        "state_id" => "a041a482-202c-4c53-99f3-79a8dab252d5"
      }

      params = Map.merge(params, %{"state_id" => state_id})

      counter_count =
        Counter
        |> Repo.all()
        |> length()

      count_before =
        Instance
        |> Repo.all()
        |> length()

      instance = Documents.create_instance(user, content_type, params)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      counter_count_after =
        Counter
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert counter_count + 1 == counter_count_after
      assert instance.raw == @valid_instance_attrs["raw"]
      assert instance.serialized == @valid_instance_attrs["serialized"]
    end

    test "does not create instance, on invalid attrs" do
      user = insert(:user)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      content_type = insert(:content_type)
      _state = insert(:state, flow: content_type.flow)

      {:error, changeset} = Documents.create_instance(user, content_type, @invalid_attrs)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               raw: ["can't be blank"],
               type: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "delete_instance/1" do
    # test "deletes an instance" do
    #   instance = insert(:instance)
    #   {:ok, _del_instance} = Documents.delete_instance(instance)

    #   refute Repo.get(Instance, instance.id)
    # end
  end

  describe "delete_uploaded_docs/1" do
    # test "returns success tuple on succesfully deleting the documents from MinIO" do
    #   instance = insert(:instance)

    #   count_before =
    #     Instance
    #     |> Repo.all()
    #     |> length()

    #   assert {:ok, _} = Documents.delete_instance(instance)

    #   count_after =
    #     Instance
    #     |> Repo.all()
    #     |> length()

    #   assert count_before == count_after + 1
    # end

    # test "returns error tuple when AWS request fails" do
    #   user = insert(:user)
    #   instance = insert(:instance, allowed_users: [user.id])

    #   ExAwsMock
    #   |> expect(
    #     :stream!,
    #     fn %ExAws.Operation.S3{} = operation ->
    #       assert operation.http_method == :get

    #       assert operation.params == %{
    #                "prefix" =>
    #                  "organisations/#{user.current_org_id}/contents/#{instance.instance_id}"
    #              }

    #       {:error, :reason}
    #     end
    #   )
    #   |> expect(
    #     :request,
    #     fn %ExAws.Operation.S3DeleteAllObjects{} ->
    #       {:error, :reason}
    #     end
    #   )

    #   {:error, :reason} = Documents.delete_uploaded_docs(user, instance)
    #   assert :ok == Mox.verify!()
    # end
  end

  describe "instance_index/2" do
    test "instance index lists the instance data" do
      user = insert(:user)
      content_type = insert(:content_type)
      i1 = insert(:instance, creator: user, content_type: content_type)
      i2 = insert(:instance, creator: user, content_type: content_type)
      instance_index = Documents.instance_index(content_type.id, %{page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.raw end)
             |> List.to_string() =~
               i1.raw

      assert instance_index.entries
             |> Enum.map(fn x -> x.raw end)
             |> List.to_string() =~ i2.raw
    end

    test "return error for invalid input" do
      instance_index = Documents.instance_index("invalid", "invalid")
      assert instance_index == {:error, :invalid_id}
    end

    test "filter by instance_id" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"instance_id" => "RO64NNYM", page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "filter by creator_id" do
      creator_1 = insert(:user, name: "User 1")
      creator_2 = insert(:user, name: "User 2")
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: creator_1,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: creator_2,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"creator_id" => creator_1.id, page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return the default index if the creator id is invalid" do
      creator_1 = insert(:user, name: "User 1")
      creator_2 = insert(:user, name: "User 2")
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: creator_1,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: creator_2,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"creator_id" => "invalid", page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list if there are no matches for creator_id" do
      creator_1 = insert(:user, name: "User 1")
      creator_2 = insert(:user, name: "User 2")
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: creator_1,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: creator_2,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{
          "creator_id" => Ecto.UUID.generate(),
          page_number: 1
        })

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "returns an empty list when there are no matches for instance_id keyword" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(
          content_type.id,
          %{
            "instance_id" => "does not exist",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "sorts by instance_id in ascending order when sort key is instance_id" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"sort" => "instance_id", page_number: 1})

      assert List.first(instance_index.entries).instance_id == i1.instance_id
      assert List.last(instance_index.entries).instance_id == i2.instance_id
    end

    test "sorts by instance_id in descending order when sort key is instance_id_desc" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"sort" => "instance_id_desc", page_number: 1})

      assert List.first(instance_index.entries).instance_id == i2.instance_id
      assert List.last(instance_index.entries).instance_id == i1.instance_id
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(instance_index.entries).raw == i1.raw
      assert List.last(instance_index.entries).raw == i2.raw
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          content_type: content_type
        )

      instance_index =
        Documents.instance_index(content_type.id, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(instance_index.entries).raw == i2.raw
      assert List.last(instance_index.entries).raw == i1.raw
    end
  end

  # TODO update the tests as per the new implementation
  describe "instance_index_of_an_organisation/2" do
    test "instance index of an organisation lists instances under an organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)

      i1 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      instance_index_under_organisation =
        Documents.instance_index_of_an_organisation(user, %{page_number: 1})

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    # TO-DO
    test "instance index returns nil if user is not part of the organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      external_user =
        insert(:user_with_organisation, owned_organisations: [insert(:organisation)])

      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)
      i1 = insert(:instance, content_type: content_type, creator: user, state: state)
      i2 = insert(:instance, content_type: content_type, creator: user, state: state)

      instance_index_under_organisation =
        Documents.instance_index_of_an_organisation(external_user, %{page_number: 1})

      refute instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    test "instance index returns if the user is a collaborator" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      flow = insert(:flow, organisation: organisation)
      state = insert(:state, organisation: organisation, flow: flow)

      user_collab =
        insert(:user_with_organisation,
          current_org_id: organisation.id,
          owned_organisations: [organisation]
        )

      i1 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id, user_collab.id]
        )

      i2 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      insert(:content_collab, user: user_collab, content: i1, state: state)

      instance_index_under_organisation =
        Documents.instance_index_of_an_organisation(user_collab, %{page_number: 1})

      instance_ids = Enum.map(instance_index_under_organisation.entries, & &1.instance_id)

      assert i1.instance_id in instance_ids
      assert i2.instance_id in instance_ids
    end

    test "instance index returns nil if the user is collaborator but not part of the organisation" do
      # TODO
    end

    # TO_DO
    test "instance index returns if the user is an approver" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      flow = insert(:flow, organisation: organisation)
      state = insert(:state, organisation: organisation, flow: flow)

      approver =
        insert(:user_with_organisation,
          current_org_id: organisation.id,
          owned_organisations: [organisation]
        )

      i1 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [approver.id]
        )

      i2 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [approver.id]
        )

      insert(:state_users, user: approver, state: state)

      instance_index_under_organisation =
        Documents.instance_index_of_an_organisation(approver, %{page_number: 1})

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    test "instance index returns nil if the user is an approver but not part of the organisation" do
      # TODO
    end

    test "return error for invalid input" do
      instance_index = Documents.instance_index_of_an_organisation("invalid", "invalid")
      assert instance_index == {:error, :invalid_id}
    end

    test "filter by instance_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "instance_id" => "RO64NNYM",
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "returns an empty list when there are no matches for instance_id keyword" do
      user = insert(:user_with_organisation)
      content_type = insert(:content_type, organisation: List.first(user.owned_organisations))

      i1 = insert(:instance, instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5", content_type: content_type)

      i2 =
        insert(:instance, instance_id: "DO745U6M67191879878164811475", content_type: content_type)

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "instance_id" => "does not exist",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # TO_DO
    test "filter by content_type_name" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)

      content_type1 = insert(:content_type, name: "Letter", organisation: organisation)

      content_type2 = insert(:content_type, name: "Contract", organisation: organisation)

      instance1 =
        insert(:instance, content_type: content_type1, state: state, allowed_users: [user.id])

      instance2 =
        insert(:instance, content_type: content_type2, state: state, allowed_users: [user.id])

      instance_index =
        Documents.instance_index_of_an_organisation(user, %{"content_type_name" => "Letter"})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance2.instance_id
    end

    # TO_DO
    test "returns an empty list when there are no EXACT matches for content_type_name keyword" do
      user = insert(:user_with_organisation)

      content_type1 =
        insert(:content_type, name: "Letter", organisation: List.first(user.owned_organisations))

      content_type2 =
        insert(:content_type,
          name: "Contract",
          organisation: List.first(user.owned_organisations)
        )

      instance1 = insert(:instance, content_type: content_type1)

      instance2 = insert(:instance, content_type: content_type2)

      instance_index =
        Documents.instance_index_of_an_organisation(user, %{"content_type_name" => "letter"})

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance2.instance_id
    end

    # TO_DO
    test "filter by creator_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "creator_id" => creator.id,
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # to_DO
    test "return an empty list if there are no matches for creator_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "creator_id" => Ecto.UUID.generate(),
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # to_do
    test "return the default index if the creator id is invalid" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      creator =
        insert(:user,
          name: "creator",
          current_org_id: organisation.id,
          owned_organisations: [organisation]
        )

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state,
          allowed_users: [creator.id, user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [creator.id, user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "creator_id" => "invalid",
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # TO_DO
    test "filter by state" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft", organisation: organisation)
      state_2 = insert(:state, state: "published", organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1,
          allowed_users: [creator.id, user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2,
          allowed_users: [creator.id, user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "state" => state_1.state,
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # TO_DO
    test "returns an empty list when the state does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft")
      state_2 = insert(:state, state: "published")

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "state" => state_1.state,
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list for invalid state" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft")
      state_2 = insert(:state, state: "published")

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "state" => "invalid",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # TO_DO
    test "filter by document instance title name" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft", organisation: organisation)
      state_2 = insert(:state, state: "published", organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1,
          serialized: %{title: "Title A", body: "Body of the content"},
          allowed_users: [creator.id, user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2,
          serialized: %{title: "Title B", body: "Body of the content"},
          allowed_users: [creator.id, user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "document_instance_title" => "Title A",
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list for invalid document instance title name" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft", organisation: organisation)
      state_2 = insert(:state, state: "published", organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1,
          serialized: %{title: "Title A", body: "Body of the content"}
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2,
          serialized: %{title: "Title B", body: "Body of the content"}
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "document_instance_title" => "Invalid Title",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    # TO_DO
    test "sorts by instance_id in ascending order when sort key is instance_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "instance_id",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).instance_id == i1.instance_id
      assert List.last(instance_index.entries).instance_id == i2.instance_id
    end

    # TO_D_
    test "sorts by instance_id in descending order when sort key is instance_id_desc" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "instance_id_desc",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).instance_id == i2.instance_id
      assert List.last(instance_index.entries).instance_id == i1.instance_id
    end

    # TO_D0
    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "inserted_at",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).raw == i1.raw
      assert List.last(instance_index.entries).raw == i2.raw
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Documents.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "inserted_at_desc",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).raw == i2.raw
      assert List.last(instance_index.entries).raw == i1.raw
    end
  end

  # to_DO
  describe "get_instance/2" do
    test "get instance shows the instance data" do
      user = insert(:user_with_organisation)

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      instance = insert(:instance, creator: user, content_type: content_type)
      i_instance = Documents.get_instance(instance.id, user)
      assert i_instance.instance_id == instance.instance_id
      assert i_instance.raw == instance.raw
    end
  end

  describe "show_instance/2" do
    # test "show instance shows and preloads creator content type layout and state instance data" do
    #   user = insert(:user_with_organisation)
    #   [organisation] = user.owned_organisations
    #   content_type = insert(:content_type, creator: user, organisation: organisation)
    #   flow = content_type.flow
    #   state = insert(:state, flow: flow, organisation: organisation)
    #   instance = insert(:instance, creator: user, content_type: content_type, state: state)

    #   i_instance = Documents.show_instance(instance.id, user)
    #   assert i_instance.instance_id == instance.instance_id
    #   assert i_instance.raw == instance.raw

    #   assert i_instance.creator.name == user.name
    #   assert i_instance.content_type.name == content_type.name
    #   assert i_instance.state.state == state.state
    # end
  end

  describe "get_built_document/1" do
    test "Get the build document of the given instance." do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, creator: user, organisation: organisation)
      flow = content_type.flow
      state = insert(:state, flow: flow, organisation: organisation)

      instance =
        insert(:instance, build: "build", creator: user, content_type: content_type, state: state)

      get_built_document = Documents.get_built_document(instance)

      assert instance.build == get_built_document.build
      assert instance.id == get_built_document.id
      assert instance.instance_id == get_built_document.instance_id
    end
  end

  # TO_D_
  describe "update_instance/2" do
    test "updates instance on valid attrs" do
      instance = insert(:instance)
      instance = Documents.update_instance(instance, @valid_instance_attrs)

      assert 1 == 1
      assert instance.raw == @valid_instance_attrs["raw"]
      assert instance.serialized == @valid_instance_attrs["serialized"]
    end

    test "returns error changeset on invalid attrs" do
      user = insert(:user)

      instance = insert(:instance, creator: user)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      {:error, changeset} = Documents.update_instance(instance, @invalid_instance_attrs)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert 1 == 1

      assert %{raw: ["can't be blank"]} ==
               errors_on(changeset)
    end
  end

  describe "update_instance_state/2" do
    test "updates state of an instance when flow ID of state and flow ID of instance's content type" do
      content_type = insert(:content_type)
      state = insert(:state, flow: content_type.flow)
      instance = insert(:instance, content_type: content_type)

      instance = Documents.update_instance_state(instance, state)

      assert instance.state_id == state.id
    end

    # test "retrurns :error when flow ID of new state doesnt match with flow ID of instance's content type" do
    #   instance = insert(:instance)
    #   state = insert(:state)
    #   assert :error = Documents.update_instance_state(instance, state)
    # end
  end

  describe "insert_bulk_build_work/6" do
    test "test creates bulk build backgroung job with valid attrs" do
      user = insert(:user)
      %{id: c_type_id} = insert(:content_type)
      %{id: state_id} = insert(:state)
      %{id: d_temp_id} = insert(:data_template)
      mapping = %{test: "map"}
      file = Plug.Upload.random_file!("test")
      tmp_file_source = "temp/bulk_build_source/" <> file

      count_before =
        Oban.Job
        |> Repo.all()
        |> length()

      {:ok, job} =
        Documents.insert_bulk_build_work(
          user,
          c_type_id,
          state_id,
          d_temp_id,
          mapping,
          %Plug.Upload{filename: file, path: file}
        )

      assert count_before + 1 ==
               Oban.Job
               |> Repo.all()
               |> length()

      assert job.args == %{
               c_type_uuid: c_type_id,
               state_uuid: state_id,
               d_temp_uuid: d_temp_id,
               mapping: mapping,
               user_uuid: user.id,
               file: tmp_file_source
             }
    end

    test "does not create bulk build backgroung job with invalid attrs" do
      response = Documents.insert_bulk_build_work(nil, nil, nil, nil, nil, nil)
      assert response == nil
    end
  end

  describe "create_or_update_counter/1" do
    test "create a row while creating an instance and write the count of instance under a content type" do
      content_type = insert(:content_type)
      {:ok, counter} = Documents.create_or_update_counter(content_type)
      assert counter.count == 1
    end

    test "update counter while adding an instance on existing content type and write total count of instances under a content type" do
      content_type = insert(:content_type)

      counter = insert(:counter, subject: "ContentType:#{content_type.id}")

      {:ok, n_counter} = Documents.create_or_update_counter(content_type)
      assert counter.count + 1 == n_counter.count
    end
  end

  describe "get_engine/1" do
    test "get engine returns the engine data" do
      engine = insert(:engine)
      e_engine = Documents.get_engine(engine.id)
      assert engine.name == e_engine.name
      assert engine.api_route == e_engine.api_route
    end
  end

  describe "add_build_history" do
    # test "add_build_history/3 Insert the build history of the given instance." do
    #   params =
    #     :build_history
    #     |> insert()
    #     |> Map.from_struct()

    #   instance = insert(:instance)
    #   user = insert(:user)

    #   count_before =
    #     History
    #     |> Repo.all()
    #     |> length()

    #   add_build_history = Documents.add_build_history(user, instance, params)

    #   count_after =
    #     History
    #     |> Repo.all()
    #     |> length()

    #   changeset = History.changeset(%History{}, params)

    #   assert changeset.valid?
    #   assert is_struct(add_build_history) == true
    #   assert is_struct(add_build_history.content.build_histories) == true
    #   assert count_before + 1 == count_after
    # end

    test "Same as add_build_history/3, but creator will not be stored." do
      params =
        :build_history
        |> insert()
        |> Map.from_struct()

      instance = insert(:instance)

      count_before =
        History
        |> Repo.all()
        |> length()

      add_build_history = Documents.add_build_history(instance, params)

      count_after =
        History
        |> Repo.all()
        |> length()

      assert is_struct(add_build_history) == true
      assert count_before + 1 == count_after
    end
  end

  describe "generate_chart/1" do
    # it has to test with real data
    test "Function to generate charts from diffrent endpoints as per input example api: https://quickchart.io/chart/create" do
      block =
        :block
        |> insert()
        |> Map.from_struct()

      # bb = %{"dataset" => "dataset", "api_route" => "api_route", "endpoint" => "blocks_api"}
      generate_chart = Documents.generate_chart(block)
      assert is_map(generate_chart)
    end
  end

  describe "generate_tex_chart/1" do
    test "Generate tex code for the chart" do
      # data = %{"dataset" => %{}, "btype" => "gantt"}
      data2 = %{"dataset" => @update_valid_attrs["dataset"]}

      dd = Documents.generate_tex_chart(data2)

      refute is_nil(dd)
      assert dd =~ ~r/(pie)/
    end
  end

  describe "create_field_type/2" do
    test "Create a field type" do
      params = string_params_with_assocs(:field_type)

      [%{"error_message" => error_message, "validation" => %{"rule" => rule, "value" => value}}] =
        params["validations"]

      user = insert(:user)

      assert {:ok, field_type} = Fields.create_field_type(user, params)
      assert field_type.id
      assert field_type.name == params["name"]
      assert field_type.description == params["description"]

      assert [
               %Validation{
                 id: _,
                 validation: %{"rule" => ^rule, "value" => ^value},
                 error_message: ^error_message
               }
             ] = field_type.validations
    end

    test "check unique name constraint" do
      user = insert(:user)
      params = string_params_with_assocs(:field_type)

      assert {:ok, _field_type} = Fields.create_field_type(user, params)
      assert {:error, _error_msg} = Fields.create_field_type(user, params)
    end
  end

  describe "do_create_instance_params/2" do
    test "Generate params to create instance." do
      k = Faker.Person.first_name()
      v = Faker.Person.last_name()
      map = %{k => v}
      d_temp = insert(:data_template)

      assert %{"raw" => _raw, "serialized" => ss} =
               Documents.do_create_instance_params(map, d_temp)

      assert is_map(ss)
      assert %{"title" => _} = ss
    end
  end
end
