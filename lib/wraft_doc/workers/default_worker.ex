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
  alias WraftDoc.Assets.Asset
  alias WraftDoc.ContentTypes
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents.Engine
  alias WraftDoc.Fields
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset

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

  @template_files_path Application.compile_env!(:wraft_doc, [:default_template_files])

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

  def perform(%Job{
        args: %{
          "organisation_id" => organisation_id,
          "current_user_id" => current_user_id,
          "flow_id" => flow_id
        },
        tags: ["wraft_templates"]
      }) do
    current_user =
      User
      |> Repo.get(current_user_id)
      |> Map.put(:current_org_id, organisation_id)

    %{id: engine_id} = Repo.get_by(Engine, name: "Pandoc")

    %{
      offer_letter_content_type: offer_letter_content_type,
      nda_content_type: nda_content_type,
      offer_letter_data_template: offer_letter_data_template,
      nda_data_template: nda_data_template
    } = load_all_templates()

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
    |> Multi.insert(
      :contract_layout,
      Layout.changeset(
        %Layout{},
        Map.merge(@wraft_layout_args, %{
          name: "Wraft Contract Layout",
          organisation_id: organisation_id,
          engine_id: engine_id,
          slug: "contract"
        })
      )
    )
    |> Multi.run(:upload_layout_asset, fn _,
                                          %{layout: layout, contract_layout: contract_layout} ->
      create_wraft_layout_assets(layout, organisation_id)
      create_wraft_layout_assets(contract_layout, organisation_id)
    end)
    |> Multi.run(:upload_theme_asset, fn _, %{theme: theme} ->
      create_wraft_theme_assets(theme, organisation_id)
    end)
    |> Multi.run(:content_type_1, fn _, %{theme: theme, layout: layout} ->
      wraft_variant =
        create_wraft_variant(current_user, theme, layout, flow_id, offer_letter_content_type)

      {:ok, wraft_variant}
    end)
    |> Multi.insert(:data_template_1, fn %{content_type_1: content_type} ->
      DataTemplate.changeset(
        %DataTemplate{},
        Map.merge(offer_letter_data_template, %{
          "content_type_id" => content_type.id,
          "creator_id" => current_user_id
        })
      )
    end)
    |> Multi.run(:content_type_2, fn _, %{theme: theme, contract_layout: layout} ->
      wraft_variant = create_wraft_variant(current_user, theme, layout, flow_id, nda_content_type)
      {:ok, wraft_variant}
    end)
    |> Multi.insert(:data_template_2, fn %{content_type_2: content_type} ->
      DataTemplate.changeset(
        %DataTemplate{},
        Map.merge(nda_data_template, %{
          "content_type_id" => content_type.id,
          "creator_id" => current_user_id
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

    layout
    |> Layout.changeset(%{"asset_id" => asset_id})
    |> Repo.update()

    {:ok, "ok"}
  end

  defp create_wraft_variant(current_user, theme, layout, flow_id, params) do
    params = create_wraft_variant_params(current_user.id, params, theme.id, layout.id, flow_id)
    ContentTypes.create_content_type(current_user, params)
  end

  defp create_wraft_variant_params(current_user_id, params, theme_id, layout_id, flow_id) do
    fields =
      Enum.map(params["fields"], fn field ->
        field_type = String.capitalize(field["type"])

        %{
          "field_type_id" => Fields.get_field_type_by_name(field_type).id,
          "key" => field["name"],
          "name" => field["name"]
        }
      end)

    Map.merge(params, %{
      "theme_id" => theme_id,
      "layout_id" => layout_id,
      "flow_id" => flow_id,
      "creator_id" => current_user_id,
      "fields" => fields
    })
  end

  def load_all_templates do
    offer_letter_template_path = Path.join(@template_files_path, "offer_letter.json")
    nda_template_path = Path.join(@template_files_path, "nda.json")

    offer_letter = load_template(offer_letter_template_path)
    nda = load_template(nda_template_path)

    %{
      offer_letter_content_type: offer_letter["content_type"],
      nda_content_type: nda["content_type"],
      offer_letter_data_template: offer_letter["data_template"],
      nda_data_template: nda["data_template"]
    }
  end

  defp load_template(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end
end
