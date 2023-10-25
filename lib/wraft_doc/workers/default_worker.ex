defmodule WraftDoc.Workers.DefaultWorker do
  @moduledoc """
  Default Oban worker for all trivial jobs.
  """
  use Oban.Worker, queue: :default

  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Document.Asset
  alias WraftDoc.Document.Engine
  alias WraftDoc.Document.Layout
  alias WraftDoc.Document.LayoutAsset
  alias WraftDoc.Document.Theme
  alias WraftDoc.Document.ThemeAsset
  alias WraftDoc.Repo

  @superadmin_role "superadmin"
  @editor_role "editor"

  @layout_file_path :wraft_doc
                    |> :code.priv_dir()
                    |> Path.join("static/wraft_files/letterhead.pdf")

  @theme_folder_path :wraft_doc |> :code.priv_dir() |> Path.join("static/wraft_files/Roboto")

  @wraft_theme_args %{
    name: "Wraft Frame",
    font: "Roboto ",
    body_color: "#111",
    primary_color: "#000",
    secondary_color: "#333"
  }

  @wraft_layout_args %{name: "Wraft Layout", description: "Wraft Layout", slug: "pletter"}

  @wraft_layout_asset_args %{
    name: @wraft_layout_args.name,
    type: "layout",
    file: %Plug.Upload{
      filename: "letterhead.pdf",
      path: @layout_file_path,
      content_type: "application/pdf"
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

  def perform(%Job{
        args: %{"organisation_id" => organisation_id, "user_id" => user_id},
        tags: ["organisation_roles"]
      }) do
    permissions = get_editor_permissions()

    Multi.new()
    |> Multi.insert(:superadmin_role, %Role{
      name: @superadmin_role,
      organisation_id: organisation_id
    })
    |> Multi.insert(:editor_role, %Role{
      name: @editor_role,
      organisation_id: organisation_id,
      permissions: permissions
    })
    |> Multi.run(:assign_role, fn _, %{superadmin_role: role} ->
      Account.create_user_role(user_id, role.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Organisation role insert failed", changeset: changeset)
        {:error, changeset}
    end
  end

  def perform(%Job{tags: ["wraft_theme_and_layout"]} = job) do
    organisation_id = job.args["organisation_id"]
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
      asset_id = create_wraft_branded_asset(organisation_id, @wraft_layout_asset_args)
      Repo.insert(%LayoutAsset{layout_id: layout.id, asset_id: asset_id})
    end)
    |> Multi.run(:upload_theme_asset, fn _, %{theme: theme} ->
      create_wraft_theme_assets(theme, organisation_id)
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

  # Private

  defp get_editor_permissions do
    "priv/repo/data/rbac/editor_permissions.csv"
    |> File.stream!()
    |> CSV.decode()
    |> Enum.map(fn {:ok, [permission]} -> permission end)
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
end
