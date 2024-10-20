defmodule WraftDoc.Workers.DefaultWorker do
  @moduledoc """
  Default Oban worker for all trivial jobs.
  """
  use Oban.Worker, queue: :default

  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Document
  alias WraftDoc.Document.Asset
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.DataTemplate
  alias WraftDoc.Document.Engine
  alias WraftDoc.Document.Layout
  alias WraftDoc.Document.LayoutAsset
  alias WraftDoc.Document.Theme
  alias WraftDoc.Document.ThemeAsset
  alias WraftDoc.Repo

  @superadmin_role "superadmin"

  @theme_folder_path Application.compile_env!(:wraft_doc, [:theme_folder])

  @wraft_theme_args %{
    name: "Wraft Frame",
    font: "Roboto ",
    body_color: "#111",
    primary_color: "#000",
    secondary_color: "#333"
  }

  @layout_file_path Application.compile_env!(:wraft_doc, [:layout_file])

  @wraft_layout_args %{
    name: "Wraft Layout",
    description: "Wraft Layout",
    slug: "pletter",
    height: "40",
    width: "40",
    unit: "cm"
  }

  @wraft_layout_asset_args %{
    name: @wraft_layout_args.name,
    type: "layout",
    file: %Plug.Upload{
      filename: "letterhead.pdf",
      content_type: "application/pdf"
    }
  }

  @content_type_params %{
    "name" => "Wraft Variant",
    "description" => "Wraft Variant",
    "prefix" => "WRA",
    "color" => "#000",
    "fields" => [
      %{
        "field_type_id" => "ed89261d-1c36-47e2-99f9-1eef44f7b3b0",
        "key" => "name",
        "name" => "name"
      },
      %{
        "field_type_id" => "e80264f3-3675-4d88-910b-1b723f97a4df",
        "key" => "email",
        "name" => "email"
      },
      %{
        "field_type_id" => "58e54a9b-faf9-47e6-8995-20450096d74b",
        "key" => "paymentSchedule",
        "name" => "paymentSchedule"
      },
      %{
        "field_type_id" => "6249b27d-f535-46d5-87f0-97dbbcc43f5f",
        "key" => "date",
        "name" => "date"
      }
    ]
  }

  @data_template_params %{
    title: "Wraft Template",
    title_template: "Wraft Template",
    data: "This is a sample template...",
    serialized: %{
      "data" =>
        Jason.encode!(%{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "content" => [
                %{"type" => "text", "text" => "This is a sample template..."}
              ]
            }
          ]
        })
    }
  }

  @impl Oban.Worker
  def perform(%Job{
        args: %{"organisation_id" => organisation_id, "user_id" => user_id},
        tags: ["personal_organisation_roles"]
      }) do
    Multi.new()
    |> Multi.insert(:role, %Role{name: @superadmin_role, organisation_id: organisation_id})
    |> Multi.insert(:user_role, fn %{role: role} ->
      %UserRole{role_id: role.id, user_id: user_id}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Personal Organisation role insert failed", changeset: changeset)
        {:error, changeset}
    end
  end

  def perform(%Job{tags: ["wraft_templates"]} = job) do
    organisation_id = job.args["organisation_id"]
    flow_id = job.args["flow_id"]
    current_user_id = job.args["current_user_id"]

    current_user =
      User
      |> Repo.get(current_user_id)
      |> Map.put(:current_org_id, organisation_id)

    %{id: engine_id} = Repo.get_by(Engine, name: "Pandoc")

    Multi.new()
    |> Multi.insert(
      :theme,
      Theme.changeset(%Theme{}, Map.put(@wraft_theme_args, :organisation_id, organisation_id))
    )
    |> Multi.insert(
      :layout,
      Layout.changeset(
        %Layout{},
        Map.merge(@wraft_layout_args, %{organisation_id: organisation_id, engine_id: engine_id})
      )
    )
    |> Multi.run(:upload_layout_asset, fn _, %{layout: layout} ->
      create_wraft_layout_assets(layout, organisation_id)
    end)
    |> Multi.run(:upload_theme_asset, fn _, %{theme: theme} ->
      create_wraft_theme_assets(theme, organisation_id)
    end)
    |> Multi.run(:content_type, fn _, %{theme: theme, layout: layout} ->
      create_wraft_variant(current_user, theme, layout, flow_id)
    end)
    |> Multi.insert(:data_template_1, fn %{content_type: content_type} ->
      DataTemplate.changeset(
        %DataTemplate{},
        Map.merge(@data_template_params, %{
          content_type_id: content_type.id,
          creator_id: current_user_id
        })
      )
    end)
    |> Multi.insert(:data_template_2, fn %{content_type: content_type} ->
      DataTemplate.changeset(
        %DataTemplate{},
        Map.merge(@data_template_params, %{
          title: "Wraft Template 2",
          title_template: "Wraft Template 2",
          content_type_id: content_type.id,
          creator_id: current_user_id
        })
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Wraft theme and layout creation failed", changeset: changeset)
        {:error, changeset}
    end
  end

  def perform(%Job{args: %{"user_id" => user_id, "roles" => role_ids}, tags: ["assign_role"]}) do
    Enum.each(role_ids, &Account.create_user_role(user_id, &1))
    :ok
  end

  # Creates a wraft branded asset, uploads the file and returns the id.
  defp create_wraft_branded_asset(organisation_id, params) do
    %Asset{}
    |> Asset.changeset(Map.put(params, :organisation_id, organisation_id))
    |> Repo.insert!()
    |> Asset.file_changeset(params)
    |> Repo.update!()
    |> Map.get(:id)
  end

  defp create_wraft_theme_assets(theme, organisation_id) do
    font_files =
      @theme_folder_path
      |> File.ls!()
      |> Enum.filter(fn file -> String.ends_with?(file, ".ttf") end)

    Enum.each(font_files, fn font_file ->
      asset_params = %{
        name: Path.basename(font_file),
        type: "theme",
        file: %Plug.Upload{
          filename: Path.basename(font_file),
          path: Path.join(@theme_folder_path, font_file),
          content_type: "application/octet-stream"
        }
      }

      asset_id = create_wraft_branded_asset(organisation_id, asset_params)
      Repo.insert(%ThemeAsset{theme_id: theme.id, asset_id: asset_id})
    end)

    {:ok, "ok"}
  end

  defp create_wraft_layout_assets(layout, organisation_id) do
    asset_params =
      Map.update!(@wraft_layout_asset_args, :file, fn upload ->
        %Plug.Upload{upload | path: @layout_file_path}
      end)

    asset_id = create_wraft_branded_asset(organisation_id, asset_params)
    Repo.insert(%LayoutAsset{layout_id: layout.id, asset_id: asset_id})

    {:ok, "ok"}
  end

  defp create_wraft_variant(current_user, theme, layout, flow_id) do
    params =
      Map.merge(@content_type_params, %{
        "theme_id" => theme.id,
        "layout_id" => layout.id,
        "flow_id" => flow_id,
        "creator_id" => current_user.id
      })

    # content_type = Document.create_content_type(current_user, params)
    # {:ok, content_type}
    case Document.create_content_type(current_user, params) do
      %ContentType{} = content_type ->
        {:ok, content_type}

      changeset = {:error, _} ->
        changeset
    end
  end
end
