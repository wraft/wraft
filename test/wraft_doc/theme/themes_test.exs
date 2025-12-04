defmodule WraftDoc.Theme.ThemesTest do
  use WraftDoc.DataCase, async: false
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.Themes
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset

  setup :verify_on_exit!

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

  @invalid_attrs %{}

  describe "create_theme/2" do
    test "create theme on valid attributes" do
      user = insert(:user_with_organisation)
      asset1 = insert(:asset, organisation: List.first(user.owned_organisations))
      asset2 = insert(:asset, organisation: List.first(user.owned_organisations))

      count_before =
        Theme
        |> Repo.all()
        |> length()

      theme =
        Themes.create_theme(
          user,
          Map.merge(@valid_theme_attrs, %{"assets" => "#{asset1.id},#{asset2.id}"})
        )

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert theme.name == @valid_theme_attrs["name"]
      assert [asset1.id, asset2.id] == Enum.map(theme.assets, & &1.id)
      assert theme.font == @valid_theme_attrs["font"]
      assert theme.typescale == @valid_theme_attrs["typescale"]
    end

    test "does not create theme on invalid attrs" do
      user = insert(:user_with_organisation)

      count_before =
        Theme
        |> Repo.all()
        |> length()

      {:error, changeset} = Themes.create_theme(user, @invalid_attrs)

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{name: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "theme_preview_file_upload/2 Upload preview_file file" do
      theme = insert(:theme)

      assert {:ok, theme} =
               Themes.theme_preview_file_upload(
                 theme,
                 %{
                   "preview_file" => %Plug.Upload{
                     filename: "invoice.pdf",
                     path: "test/helper/invoice.pdf"
                   }
                 }
               )

      # HACK Theme preview currently not in use, just commented for now
      # dir = "uploads/theme/theme_preview/#{theme.id}"
      # assert {:ok, ls} = File.ls(dir)
      # assert File.exists?(dir)
      # assert Enum.member?(ls, "invoice.pdf")
      assert theme.preview_file.file_name =~ "invoice.pdf"
    end
  end

  describe "theme_index/2" do
    test "theme index lists the theme data" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, creator: user, organisation: organisation)
      t2 = insert(:theme, creator: user, organisation: organisation)
      theme_index = Themes.theme_index(user, %{page_number: 1})

      themes =
        theme_index.entries
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert themes =~ t1.name
      assert themes =~ t2.name
    end

    test "filter by name" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      t2 = insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Themes.theme_index(user, %{"name" => "First", page_number: 1})

      themes =
        theme_index.entries
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert themes =~ t1.name
      refute themes =~ t2.name
    end

    test "returns an empty list when there are no matches for the name keyword" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Themes.theme_index(user, %{"name" => "Does not exist", page_number: 1})

      assert theme_index.entries == []
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      t2 = insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Themes.theme_index(user, %{"sort" => "name", page_number: 1})

      assert List.first(theme_index.entries).name == t1.name
      assert List.last(theme_index.entries).name == t2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      t2 = insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Themes.theme_index(user, %{"sort" => "name_desc", page_number: 1})

      assert List.first(theme_index.entries).name == t2.name
      assert List.last(theme_index.entries).name == t1.name
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: organisation
        )

      t2 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: organisation
        )

      theme_index = Themes.theme_index(user, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(theme_index.entries).name == t1.name
      assert List.last(theme_index.entries).name == t2.name
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: organisation
        )

      t2 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: organisation
        )

      theme_index = Themes.theme_index(user, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(theme_index.entries).name == t2.name
      assert List.last(theme_index.entries).name == t1.name
    end
  end

  describe "get_theme/2" do
    test "get theme returns the theme data" do
      user = insert(:user_with_organisation)
      theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))
      t_theme = Themes.get_theme(theme.id, user)
      assert t_theme.name == theme.name
      assert t_theme.font == theme.font
    end
  end

  describe "show_theme/2" do
    test "show theme returns the theme data and preloads the creator" do
      user = insert(:user_with_organisation)
      theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))
      t_theme = Themes.show_theme(theme.id, user)
      assert t_theme.name == theme.name
      assert t_theme.font == theme.font

      assert t_theme.creator.name == user.name
    end
  end

  describe "update_theme/2" do
    test "update theme on valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      theme = insert(:theme, creator: user, organisation: organisation)
      asset1 = insert(:asset, organisation: organisation)
      asset2 = insert(:asset, organisation: organisation)

      count_before =
        Theme
        |> Repo.all()
        |> length()

      theme =
        Themes.update_theme(
          theme,
          user,
          Map.merge(@valid_theme_attrs, %{"assets" => "#{asset1.id},#{asset2.id}"})
        )

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert [asset1.id, asset2.id] == Enum.map(theme.assets, & &1.id)
      assert theme.name == @valid_theme_attrs["name"]
      assert theme.font == @valid_theme_attrs["font"]
      assert theme.typescale == @valid_theme_attrs["typescale"]
    end

    test "returns error on invalid attrs" do
      user = insert(:user)
      theme = insert(:theme, creator: user)

      count_before =
        Theme
        |> Repo.all()
        |> length()

      {:error, changeset} =
        Themes.update_theme(theme, user, %{name: nil, font: nil, typescale: nil, file: nil})

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               name: ["can't be blank"],
               font: ["can't be blank"],
               typescale: ["can't be blank"]
             } ==
               errors_on(changeset)
    end
  end

  describe "delete_theme/1" do
    test "delete theme deletes and return the theme data" do
      user = insert(:user_with_organisation)
      theme = insert(:theme, organisation: List.first(user.owned_organisations))
      asset = insert(:asset, organisation: List.first(user.owned_organisations))
      insert(:theme_asset, theme: theme, asset: asset)

      count_before_asset = Asset |> Repo.all() |> length()
      count_before_theme_asset = ThemeAsset |> Repo.all() |> length()
      count_before_theme = Theme |> Repo.all() |> length()

      ExAwsMock
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} = operation ->
          assert operation.http_method == :get

          assert operation.params == %{
                   "prefix" =>
                     "organisations/#{user.current_org_id}/theme/theme_preview/#{theme.id}"
                 }

          {
            :ok,
            %{
              body: %{
                contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
              }
            }
          }
        end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} -> {:ok, %{body: "", status_code: 204}} end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} = operation ->
          assert operation.http_method == :get

          assert operation.params == %{
                   "prefix" => "organisations/#{user.current_org_id}/assets/#{asset.id}"
                 }

          {
            :ok,
            %{
              body: %{
                contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
              }
            }
          }
        end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} -> {:ok, %{body: "", status_code: 204}} end
      )

      {:ok, t_theme} = Themes.delete_theme(theme)

      count_after_asset = Asset |> Repo.all() |> length()
      count_after_theme_asset = ThemeAsset |> Repo.all() |> length()
      count_after_theme = Theme |> Repo.all() |> length()

      assert count_before_theme_asset - 1 == count_after_theme_asset
      assert count_before_asset - 1 == count_after_asset
      assert count_before_theme - 1 == count_after_theme
      assert t_theme.name == theme.name
      assert t_theme.font == theme.font
      assert t_theme.typescale == theme.typescale
    end
  end
end
