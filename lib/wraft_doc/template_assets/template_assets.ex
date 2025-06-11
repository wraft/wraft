defmodule WraftDoc.TemplateAssets do
  @moduledoc """
  Context module for Template Assets.
  """

  import Ecto
  import Ecto.Query

  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Client.Minio
  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Engine
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Layouts
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDoc.TemplateAssets.WraftJsonSchema
  alias WraftDoc.Themes
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Utils.FileHelper
  alias WraftDoc.Utils.ProsemirrorToMarkdown

  @required_items ["layout", "theme", "flow", "variant", "data_template", "frame"]
  @allowed_folders ["fonts", "assets", "frame"]
  @allowed_files ["template.json", "wraft.json"]
  @font_style_name ~w(Regular Italic Bold BoldItalic)

  @doc """
  Create a template asset.
  """
  # TODO - write test
  @spec create_template_asset(User.t() | nil, map()) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t()}
  def create_template_asset(current_user, params) do
    Multi.new()
    |> Multi.run(:asset, fn _, _ ->
      Assets.create_asset(current_user, Map.merge(params, %{"type" => "template_asset"}))
    end)
    |> public_template_asset_multi(current_user, params)
    |> Multi.update(
      :template_asset_thumbnail,
      fn %{template_asset: template_asset} ->
        TemplateAsset.thumbnail_changeset(template_asset, params)
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{template_asset: template_asset}} ->
        {:ok, Repo.preload(template_asset, [:asset])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp public_template_asset_multi(multi, nil, params) do
    Multi.insert(
      multi,
      :template_asset,
      fn %{asset: %Asset{id: asset_id}} ->
        TemplateAsset.changeset(%TemplateAsset{}, Map.put(params, "asset_id", asset_id))
      end
    )
  end

  defp public_template_asset_multi(
         multi,
         %{current_org_id: organisation_id} = current_user,
         params
       ) do
    Multi.insert(
      multi,
      :template_asset,
      fn %{asset: %Asset{id: asset_id}} ->
        current_user
        |> build_assoc(:template_assets)
        |> TemplateAsset.changeset(
          Map.merge(params, %{"organisation_id" => organisation_id, "asset_id" => asset_id})
        )
      end
    )
  end

  @doc """
  Index of all template assets in an organisation.
  """
  # TODO - Write tests
  @spec template_asset_index(User.t(), map()) :: map()
  def template_asset_index(%{current_org_id: organisation_id}, params) do
    query =
      from(a in TemplateAsset,
        where: a.organisation_id == ^organisation_id,
        order_by: [desc: a.inserted_at],
        preload: [:asset]
      )

    Repo.paginate(query, params)
  end

  def template_asset_index(_, _), do: {:error, :fake}

  @doc """
  Show a template asset.
  """
  # TODO - write tests
  @spec show_template_asset(Ecto.UUID.t(), User.t()) :: TemplateAsset.t() | nil
  def show_template_asset(<<_::288>> = template_asset_id, user) do
    template_asset_id
    |> get_template_asset(user)
    |> Repo.preload([:creator, :asset])
  end

  @doc """
  Get a template asset from its UUID.
  """
  # TODO - Write tests
  @spec get_template_asset(Ecto.UUID.t(), User.t()) :: TemplateAsset.t() | nil
  def get_template_asset(<<_::288>> = id, %{current_org_id: org_id}) do
    TemplateAsset
    |> Repo.get_by(id: id, organisation_id: org_id)
    |> Repo.preload(:asset)
  end

  def get_template_asset(_, _), do: nil

  def get_template_asset(<<_::288>> = id) do
    TemplateAsset
    |> Repo.get(id)
    |> Repo.preload(:asset)
  end

  def get_template_asset(_), do: nil

  @doc """
  Delete a template asset.
  """
  # TODO - Write tests
  @spec delete_template_asset(TemplateAsset.t()) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t() | String.t()}
  def delete_template_asset(
        %TemplateAsset{
          organisation_id: organisation_id,
          asset: %Asset{id: asset_id, file: %{file_name: file_name} = asset}
        } = template_asset
      ) do
    "organisations/#{organisation_id}/assets/#{asset_id}/#{file_name}"
    |> Minio.delete_file()
    |> case do
      {:ok, _} ->
        Repo.delete(asset)
        Repo.delete(template_asset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Imports template asset.
  """
  @spec import_template(User.t(), binary(), list()) ::
          DataTemplate.t() | {:error, any()}
  def import_template(current_user, downloaded_file_binary, opts \\ []) do
    with {:ok, entries} <- FileHelper.get_file_entries(downloaded_file_binary),
         {:ok, template_map} <- FileHelper.get_wraft_json(downloaded_file_binary),
         contained_items <- has_items(template_map),
         :ok <- validate_required_items(contained_items, opts) do
      prepare_template(
        template_map,
        current_user,
        downloaded_file_binary,
        entries,
        opts
      )
    end
  end

  @doc """
  Returns items from wraft_json.
  """
  @spec has_items(map()) :: list()
  def has_items(%{"items" => items}) do
    Enum.filter(@required_items, fn key ->
      Map.has_key?(items, key)
    end)
  end

  @doc """
  Validates required items.
  """
  @spec validate_required_items(list(), list()) :: :ok | list()
  def validate_required_items(contained_items, opts) do
    optional_ids = [
      Keyword.get(opts, :layout_id),
      Keyword.get(opts, :theme_id),
      Keyword.get(opts, :flow_id),
      Keyword.get(opts, :content_type_id),
      Keyword.get(opts, :frame_id)
    ]

    (@required_items -- ["frame"])
    |> Enum.filter(fn key ->
      key not in contained_items &&
        is_nil(Enum.at(optional_ids, Enum.find_index(@required_items, &(&1 == key))))
    end)
    |> case do
      [] ->
        :ok

      missing_items ->
        missing_items
        |> Enum.map(fn item ->
          %{
            item: item,
            message:
              "Either '#{item}' must be in the ZIP or the corresponding #{item}_id must be provided"
          }
        end)
        |> then(&{:error, %{missing_items: &1}})
    end
  end

  @doc """
  Format optional params.
  """
  @spec format_opts(map()) :: list()
  def format_opts(params) do
    Enum.reduce([:theme_id, :flow_id, :layout_id, :content_type_id, :frame_id], [], fn key, acc ->
      case Map.get(params, Atom.to_string(key)) do
        nil -> acc
        value -> [{key, value} | acc]
      end
    end)
  end

  @doc """
  Pre-import template asset returns existing and missing items.
  """
  @spec pre_import_template(binary()) :: {:ok, map()} | {:error, any()}
  def pre_import_template(downloaded_file_binary) do
    {:ok, %{"items" => template_map}} = FileHelper.get_wraft_json(downloaded_file_binary)

    existing_items =
      %{
        theme: Map.get(template_map, "theme"),
        layout: Map.get(template_map, "layout"),
        frame: Map.get(template_map, "frame"),
        flow: Map.get(template_map, "flow"),
        data_template: Map.get(template_map, "data_template"),
        variant: Map.get(template_map, "variant")
      }
      |> Enum.filter(fn {_key, value} -> value != nil end)
      |> Enum.into(%{})

    missing_items = @required_items -- has_items(template_map)

    {:ok, %{existing_items: existing_items, missing_items: missing_items}}
  end

  @doc """
  Download zip file from storage as binary.
  """
  @spec download_zip_from_storage(TemplateAsset.t() | Asset.t()) ::
          {:error, String.t()} | {:ok, binary()}

  def download_zip_from_storage(%TemplateAsset{asset: %{file: %{file_name: file_name}}}) do
    file_name = get_rootname(file_name)

    downloaded_file_binary =
      Minio.get_object("public/templates/#{file_name}/#{file_name}.zip")

    {:ok, downloaded_file_binary}
  rescue
    error -> {:error, error.message}
  end

  def download_zip_from_storage(%Asset{
        id: asset_id,
        organisation_id: organisation_id,
        file: %{file_name: file_name}
      }) do
    downloaded_file_binary =
      Minio.get_object("organisations/#{organisation_id}/assets/#{asset_id}/#{file_name}")

    {:ok, downloaded_file_binary}
  rescue
    error -> {:error, error.message}
  end

  @spec template_asset_file_list(binary()) ::
          {:ok, list()} | {:error, String.t()}
  def template_asset_file_list(file_binary) do
    file_binary
    |> FileHelper.get_file_entries()
    |> case do
      {:ok, entries} ->
        entries
        |> filter_entries()
        |> Enum.split_with(fn entry ->
          String.ends_with?(entry, "/")
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  defp filter_entries(entries) do
    Enum.reduce(entries, [], fn %{file_name: file_name}, acc ->
      if Enum.any?(@allowed_folders, &String.starts_with?(file_name, "#{&1}/")) ||
           file_name in @allowed_files do
        [file_name | acc]
      else
        acc
      end
    end)
  end

  defp prepare_template(
         template_map,
         current_user,
         downloaded_file,
         entries,
         opts
       ) do
    case prepare_template_transaction(
           template_map,
           current_user,
           downloaded_file,
           entries,
           opts
         ) do
      {:ok, result} ->
        Logger.info("Theme, Layout, Flow, variant created successfully.")

        %{
          theme: Map.get(result, :theme),
          flow: Map.get(result, :flow),
          frame: Map.get(result, :frame),
          layout: Map.get(result, :layout),
          variant: Map.get(result, :content_type),
          data_template: Map.get(result, :data_template)
        }
        |> Enum.filter(fn {_key, value} -> value != nil end)
        |> Enum.into(%{})
        |> then(&{:ok, &1})

      {:error, _failed_operation, error, _changes_so_far} ->
        Logger.error("Failed to process. Error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp prepare_template_transaction(
         template_map,
         current_user,
         downloaded_file,
         entries,
         opts
       ) do
    build_multi()
    |> add_theme_step(template_map, current_user, downloaded_file, entries)
    |> add_flow_step(template_map, current_user)
    |> add_frame_step(template_map, current_user, downloaded_file, entries)
    |> add_layout_step(template_map, current_user, downloaded_file, entries, opts)
    |> add_variant_step(template_map, current_user, opts)
    |> add_data_template_step(template_map, current_user, downloaded_file, opts)
    |> Repo.transaction()
  end

  defp build_multi, do: Multi.new()

  defp add_theme_step(
         multi,
         %{"items" => %{"theme" => theme}, "packageContents" => %{"fonts" => fonts}},
         current_user,
         downloaded_file,
         entries
       ) do
    Multi.run(multi, :theme, fn _repo, _changes ->
      theme
      |> update_conflicting_name(Theme, current_user)
      |> Map.merge(%{"fonts" => fonts})
      |> prepare_theme(current_user, downloaded_file, entries)
    end)
  end

  defp add_theme_step(multi, _template_map, _current_user, _downloaded_file, _entries), do: multi

  defp add_flow_step(
         multi,
         %{"items" => %{"flow" => flow}},
         %{current_org_id: org_id} = current_user
       ) do
    flow =
      flow
      |> Map.merge(%{"organisation_id" => org_id})
      |> update_conflicting_name(Flow, current_user)

    multi
    |> Multi.insert(
      :flow,
      current_user
      |> build_assoc(:flows)
      |> Flow.changeset(flow)
    )
    |> Multi.run(:default_flow_states, fn _repo, %{flow: flow} ->
      current_user
      |> Enterprise.create_default_states(flow)
      |> then(&{:ok, &1})
    end)
  end

  defp add_flow_step(multi, _template_map, _current_user), do: multi

  defp add_layout_step(
         multi,
         %{
           "items" => %{"layout" => layout},
           "packageContents" => %{"assets" => assets}
         },
         current_user,
         downloaded_file,
         entries,
         opts
       ) do
    Multi.run(multi, :layout, fn _repo, changes ->
      frame_id = Keyword.get(opts, :frame_id, nil)
      frame = Map.get(changes, :frame, nil)

      layout
      |> update_conflicting_name(Layout, current_user)
      |> Map.merge(%{"file_path" => get_pdf_asset_path(assets, "layout")})
      |> prepare_layout(downloaded_file, current_user, entries, frame_id || (frame && frame.id))
    end)
  end

  defp add_layout_step(multi, _template_map, _current_user, _downloaded_file, _entries, _opts),
    do: multi

  defp add_frame_step(
         multi,
         %{"items" => %{"frame" => frame_json_path}},
         current_user,
         downloaded_file,
         entries
       ) do
    Multi.run(multi, :frame, fn _repo, _changes ->
      prepare_frame(current_user, downloaded_file, entries, frame_json_path)
    end)
  end

  defp add_frame_step(multi, _template_map, _current_user, _downloaded_file, _entries), do: multi

  defp prepare_frame(current_user, downloaded_file, entries, frame_json_path) do
    with {:ok, file_path} <- extract_frame_files(downloaded_file, entries),
         {:ok, %{"metadata" => %{"name" => frame_name}} = _wraft_json} <-
           get_frame_wraft_json(downloaded_file, frame_json_path),
         params <- create_asset_from_zip(file_path),
         {:ok, %Frame{} = frame} <-
           create_or_get_frame(current_user, params, frame_name) do
      {:ok, frame}
    end
  end

  defp get_frame_wraft_json(downloaded_file, frame_json_path) do
    downloaded_file
    |> FileHelper.extract_file_content(frame_json_path)
    |> case do
      {:ok, wraft_json} ->
        Jason.decode(wraft_json)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_or_get_frame(
         %User{current_org_id: organisation_id} = current_user,
         params,
         frame_name
       ) do
    Frame
    |> Repo.get_by(name: frame_name, organisation_id: organisation_id)
    |> case do
      nil ->
        Frames.create_frame(current_user, params)

      frame ->
        {:ok, frame}
    end
  end

  defp create_asset_from_zip(file_path) do
    %{
      "file" => %Plug.Upload{
        filename: Path.basename(file_path),
        content_type: "application/zip",
        path: file_path
      },
      "type" => "template_asset"
    }
  end

  def extract_frame_files(file_binary, entries) do
    {:ok, temp_dir} = Briefly.create(directory: true)

    entries
    |> Enum.filter(fn entry -> String.starts_with?(entry.file_name, "frame/") end)
    |> Enum.each(fn %{file_name: file_name} ->
      full_path = Path.join(temp_dir, String.replace_prefix(file_name, "frame/", ""))

      if String.ends_with?(file_name, "/") do
        File.mkdir_p!(full_path)
      else
        File.mkdir_p!(Path.dirname(full_path))

        {:ok, content} = FileHelper.extract_file_content(file_binary, file_name)
        File.write!(full_path, content)
      end
    end)

    create_zip_of_extracted_files(temp_dir)
  end

  defp create_zip_of_extracted_files(temp_dir) do
    zip_path = Path.join(temp_dir, "frame_files.zip")

    with file_list when file_list != [] <- file_list(temp_dir),
         {:ok, _} <-
           :zip.create(
             String.to_charlist(zip_path),
             Enum.map(file_list, &String.to_charlist/1),
             cwd: String.to_charlist(temp_dir)
           ) do
      {:ok, zip_path}
    else
      [] -> {:error, "No files to zip"}
      {:error, reason} -> {:error, "Failed to create zip: #{inspect(reason)}"}
    end
  end

  defp file_list(dir) do
    dir
    |> Path.join("**")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
  end

  defp add_variant_step(multi, %{"items" => %{"variant" => variant}}, current_user, opts) do
    theme_id = Keyword.get(opts, :theme_id, nil)
    layout_id = Keyword.get(opts, :layout_id, nil)
    flow_id = Keyword.get(opts, :flow_id, nil)

    Multi.run(multi, :content_type, fn _repo, changes ->
      theme = Map.get(changes, :theme, nil)
      layout = Map.get(changes, :layout, nil)
      flow = Map.get(changes, :flow, nil)

      variant
      |> update_conflicting_name(ContentType, current_user)
      |> prepare_content_type(
        current_user,
        theme_id || (theme && theme.id),
        layout_id || (layout && layout.id),
        flow_id || (flow && flow.id)
      )
    end)
  end

  defp add_variant_step(multi, _template_map, _current_user, _opts), do: multi

  defp add_data_template_step(
         multi,
         %{"items" => %{"data_template" => data_template}},
         current_user,
         downloaded_file,
         opts
       ) do
    Multi.run(multi, :data_template, fn _repo, changes ->
      changes
      |> get_content_type(opts)
      |> case do
        {:ok, %ContentType{} = content_type} ->
          data_template
          |> update_conflicting_name(DataTemplate, current_user)
          |> then(&prepare_data_template(current_user, &1, downloaded_file, content_type))

        error ->
          error
      end
    end)
  end

  defp add_data_template_step(multi, _template_map, _current_user, _downloaded_file, _opts),
    do: multi

  defp get_content_type(changes, opts) do
    changes
    |> Map.get(:content_type, nil)
    |> case do
      nil ->
        opts
        |> Keyword.get(:content_type_id)
        |> get_content_type_from_id()

      content_type ->
        {:ok, content_type}
    end
  end

  defp get_content_type_from_id(nil), do: {:error, "content type id not found"}

  defp get_content_type_from_id(id), do: {:ok, ContentTypes.get_content_type_from_id(id)}

  defp get_engine(engine) do
    case engine do
      "pandoc/latex" -> Documents.get_engine_by_name("Pandoc")
      "pandoc/typst" -> Documents.get_engine_by_name("Pandoc + Typst")
    end
  end

  defp prepare_theme(theme, current_user, downloaded_file, entries) do
    with asset_ids <- prepare_theme_assets(entries, downloaded_file, current_user),
         params <- prepare_theme_attrs(theme, asset_ids),
         %Theme{} = theme <- Themes.create_theme(current_user, params) do
      {:ok, theme}
    end
  end

  defp prepare_theme_assets(entries, downloaded_file, current_user) do
    entries
    |> get_theme_font_file_entries()
    |> extract_and_save_fonts(downloaded_file, current_user)
  end

  defp prepare_theme_attrs(%{"name" => name, "colors" => colors, "fonts" => fonts}, asset_ids) do
    font_name =
      fonts
      |> List.first()
      |> Map.get("fontName", name)
      |> Path.rootname()
      |> String.replace(~r/[-\s]/, "")

    Map.merge(colors, %{
      "name" => name,
      "font" => font_name,
      "primary_color" => colors["primaryColor"],
      "secondary_color" => colors["secondaryColor"],
      "body_color" => colors["bodyColor"],
      "assets" => asset_ids
    })
  end

  defp get_theme_font_file_entries(entries) do
    Enum.filter(entries, fn entry ->
      case Regex.run(~r/^theme\/.*-(?<style>\w+)\.(otf|ttf)$/i, entry.file_name) do
        [_, style, _] when style in @font_style_name -> true
        _ -> false
      end
    end)
  end

  defp extract_and_save_fonts(entries, downloaded_zip_file, current_user) do
    entries
    |> Task.async_stream(&create_theme_asset(&1, downloaded_zip_file, current_user),
      timeout: 60_000,
      max_concurrency: 4
    )
    |> Enum.reduce("", fn
      {:ok, <<_::288>> = asset_id}, "" ->
        "#{asset_id}"

      {:ok, <<_::288>> = asset_id}, acc ->
        "#{acc},#{asset_id}"

      {:ok, {:error, _reason}}, acc ->
        acc

      {:exit, reason}, acc ->
        Logger.error("Saving font failed with reason: #{inspect(reason)}")
        acc
    end)
  end

  defp create_theme_asset(entry, downloaded_zip_file, current_user) do
    with {:ok, content} <- FileHelper.extract_file_content(downloaded_zip_file, entry.file_name),
         {:ok, temp_file_path} <- write_temp_file(content),
         asset_params = prepare_theme_asset_params(entry, temp_file_path, current_user),
         {:ok, asset} <- Assets.create_asset(current_user, asset_params) do
      asset.id
    else
      error ->
        Logger.error("""
        Failed to create theme asset: #{inspect(entry.file_name)}.
        Error: #{inspect(error)}.
        """)

        {:error, error}
    end
  end

  defp write_temp_file(content) do
    Briefly.create!()
    |> File.write(content)
    |> then(&{:ok, &1})
  end

  defp prepare_theme_asset_params(
         %{file_name: file_name} = _entry,
         temp_file_path,
         %{id: user_id} = _current_user
       ) do
    %{
      "name" => Path.basename(file_name),
      "type" => "theme",
      "file" => %Plug.Upload{
        filename: Path.basename(file_name),
        content_type: get_file_type(file_name),
        path: temp_file_path
      },
      "creator_id" => user_id
    }
  end

  defp get_file_type(filename) do
    filename
    |> Path.extname()
    |> case do
      ".otf" -> "font/otf"
      ".ttf" -> "font/ttf"
      ".pdf" -> "application/pdf"
      ".tex" -> "application/x-tex"
      _ -> "application/octet-stream"
    end
  end

  defp prepare_layout(
         %{"engine" => engine, "file_path" => file_path} = layouts,
         downloaded_file,
         current_user,
         entries,
         frame_id
       ) do
    with %Engine{id: engine_id} <- get_engine(engine),
         asset_id <- prepare_layout_assets(entries, file_path, downloaded_file, current_user),
         params <- prepare_layout_attrs(layouts, engine_id, asset_id, frame_id),
         %Engine{} = engine <- Frames.get_engine_by_frame_type(params),
         %Layout{} = layout <- Layouts.create_layout(current_user, engine, params) do
      {:ok, layout}
    end
  end

  defp prepare_layout_assets(entries, file_path, downloaded_file, current_user) do
    entries
    |> get_layout_file_entry(file_path)
    |> extract_and_prepare_layout_asset(downloaded_file, current_user)
  end

  defp get_pdf_asset_path(assets, type) do
    Enum.find(assets, fn asset ->
      asset["type"] == type and String.ends_with?(asset["path"], ".pdf")
    end)["path"]
  end

  defp prepare_layout_attrs(layout, engine_id, asset_id, frame_id) do
    %{
      "name" => layout["name"],
      "meta" => layout["meta"],
      "description" => layout["description"],
      "slug" => layout["slug"],
      "engine_id" => engine_id,
      "assets" => asset_id,
      "width" => 40,
      "height" => 40,
      "unit" => "cm",
      "frame_id" => frame_id
    }
  end

  defp get_layout_file_entry(entries, file_path) do
    Enum.find(entries, fn entry ->
      entry.file_name == file_path
    end)
  end

  defp extract_and_prepare_layout_asset(entry, downloaded_zip_file, current_user) do
    with {:ok, content} <- FileHelper.extract_file_content(downloaded_zip_file, entry.file_name),
         {:ok, temp_file_path} <- write_temp_file(content),
         asset_params <- prepare_layout_asset_params(entry, temp_file_path, current_user),
         {:ok, asset} <- Assets.create_asset(current_user, asset_params) do
      asset.id
    else
      error ->
        Logger.error(
          "Failed to process entry: #{inspect(entry.file_name)}. Error: #{inspect(error)}"
        )

        nil
    end
  end

  defp prepare_layout_asset_params(entry, temp_file_path, current_user) do
    %{
      "name" => Path.basename(entry.file_name),
      "type" => "layout",
      "file" => %Plug.Upload{
        filename: Path.basename(entry.file_name),
        content_type: get_file_type(entry.file_name),
        path: temp_file_path
      },
      "creator_id" => current_user.id
    }
  end

  defp prepare_content_type(variant, current_user, theme_id, layout_id, flow_id) do
    with params <-
           prepare_content_type_attrs(variant, current_user, theme_id, layout_id, flow_id),
         %ContentType{} = content_type <- ContentTypes.create_content_type(current_user, params) do
      {:ok, content_type}
    end
  end

  defp prepare_content_type_attrs(
         %{
           "name" => name,
           "description" => description,
           "color" => color,
           "prefix" => prefix,
           "type" => type
         } = content_type,
         %{id: user_id, current_org_id: current_org_id} = _current_user,
         theme_id,
         layout_id,
         flow_id
       ) do
    field_types = Repo.all(from(ft in FieldType, select: {ft.name, ft.id}))
    field_type_map = Map.new(field_types)

    fields =
      Enum.map(content_type["fields"], fn field ->
        field_type = String.capitalize(field["type"])

        %{
          "field_type_id" => Map.get(field_type_map, field_type),
          "key" => field["name"],
          "name" => field["name"]
        }
      end)

    %{
      "name" => name,
      "description" => description,
      "color" => color,
      "prefix" => prefix,
      "type" => type,
      "layout_id" => layout_id,
      "flow_id" => flow_id,
      "theme_id" => theme_id,
      "fields" => fields,
      "organisation_id" => current_org_id,
      "creator_id" => user_id
    }
  end

  defp prepare_data_template(current_user, template_map, downloaded_file, content_type) do
    with params when is_map(params) <-
           prepare_data_template_attrs(template_map, downloaded_file, content_type.id),
         {:ok, %DataTemplate{} = data_template} <-
           DataTemplates.create_data_template(current_user, content_type, params) do
      {:ok, data_template}
    end
  end

  defp prepare_data_template_attrs(template_map, downloaded_file, content_type_id) do
    case get_data_template_prosemirror(downloaded_file) do
      {:ok, serialized_prosemirror_data} ->
        markdown_data =
          serialized_prosemirror_data
          |> Jason.decode!()
          |> ProsemirrorToMarkdown.convert()

        %{
          "c_type_id" => content_type_id,
          "title" => template_map["title"],
          "title_template" => template_map["title_template"],
          "data" => markdown_data,
          "serialized" => %{"data" => serialized_prosemirror_data}
        }

      {:error, error} ->
        Logger.error("Failed to prepare data template. Error: #{inspect(error)}")
        {:error, error}
    end
  end

  # Not using now for future use
  # defp get_data_template_md(downloaded_file) do
  #   case FileHelper.get_file_entries(downloaded_file) do
  #     {:ok, entries} ->
  #       template_md = Enum.find(entries, fn entry -> entry.file_name =~ ~r/^.*\.md$/i end)
  #       template_md.file_name
  #     _ ->
  #       Logger.error(" template data not found")
  #   end
  # end

  defp get_data_template_prosemirror(downloaded_file) do
    with {:ok, template_json} <-
           FileHelper.extract_file_content(downloaded_file, "template.json"),
         serialized_prosemirror <- Jason.decode!(template_json) do
      {:ok, serialized_prosemirror["data"]}
    end
  end

  @doc """
  Validates the contents of a ZIP file containing a template asset.
  """
  @spec template_zip_validator(binary(), list()) :: {:ok, String.t()} | {:error, String.t()}
  def template_zip_validator(file_binary, file_entries_in_zip) do
    with {:ok, wraft_json} <- FileHelper.get_wraft_json(file_binary),
         #  :ok <- validate_wraft_json(wraft_json),
         :ok <- validate_file_entries(wraft_json, file_entries_in_zip),
         :ok <- check_allowed_files_exists(wraft_json, file_entries_in_zip) do
      {:ok, "Template file is valid"}
    end
  end

  defp validate_file_entries(wraft_json, entries) do
    items = has_items(wraft_json)

    {folders, files} =
      Enum.split_with(entries, fn entry ->
        String.ends_with?(entry, "/")
      end)

    []
    |> collect_missing_files(files)
    |> collect_missing_folders(folders, items)
    |> validate_layout(files, items)
    |> validate_theme(files, items)
    |> validate_data_template(files, items)
    |> validate_frame(files, items)
    |> case do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp collect_missing_files(errors, files) do
    missing_files =
      @allowed_files
      |> Enum.filter(&(&1 not in files))
      |> Enum.map(&%{type: "file_validation_error", message: "Missing required file: #{&1}"})

    errors ++ missing_files
  end

  defp collect_missing_folders(errors, folders, items) do
    missing_folders =
      items
      |> Enum.flat_map(fn
        "theme" -> ["fonts/"]
        "layout" -> ["assets/"]
        "frame" -> ["frame/"]
        _ -> []
      end)
      |> Enum.filter(fn folder ->
        not Enum.any?(folders, &String.starts_with?(&1, folder))
      end)
      |> Enum.map(&%{type: "folder_error", message: "Missing required folder: #{&1}"})

    errors ++ missing_folders
  end

  defp validate_layout(errors, files, items) do
    if "layout" in items do
      files
      |> Enum.any?(fn file ->
        String.starts_with?(file, "assets/") and String.ends_with?(file, ".pdf")
      end)
      |> case do
        true -> errors
        false -> [%{type: "layout_error", message: "Missing PDF file in assets"} | errors]
      end
    else
      errors
    end
  end

  defp validate_theme(errors, files, items) do
    if "theme" in items do
      regular_font_missing =
        not Enum.any?(files, fn file ->
          String.starts_with?(file, "fonts/") and String.contains?(file, "Regular")
        end)

      if regular_font_missing do
        [%{type: "theme_error", message: "Missing Regular font file in fonts"} | errors]
      else
        errors
      end
    else
      errors
    end
  end

  defp validate_data_template(errors, files, items) do
    if "data_template" in items do
      template_json_missing = not Enum.any?(files, fn file -> file == "template.json" end)

      if template_json_missing do
        [%{type: "data_template_error", message: "Missing template.json file"} | errors]
      else
        errors
      end
    else
      errors
    end
  end

  defp validate_frame(errors, files, items) do
    if "frame" in items do
      missing_frame_files =
        ["frame/template.typst", "frame/default.typst"]
        |> Enum.filter(&(&1 not in files))
        |> Enum.map(&%{type: "frame_error", message: "Missing required file in frame/: #{&1}"})

      errors ++ missing_frame_files
    else
      errors
    end
  end

  defp check_allowed_files_exists(wraft_json, entries) do
    wraft_json
    |> FileHelper.get_allowed_files_from_wraft_json()
    |> Kernel.--(entries)
    |> case do
      [] ->
        :ok

      missing_files ->
        missing_files
        |> Enum.map(
          &%{
            type: "file_validation_error",
            message: "Missing file mentioned in wraft_json: #{&1}"
          }
        )
        |> then(&{:error, &1})
    end
  end

  @doc """
  Validates template asset wraft_json.
  """
  @spec validate_wraft_json(map()) :: :ok | {:error, list(String.t())}
  def validate_wraft_json(wraft_json) do
    WraftJsonSchema.schema()
    |> ExJsonSchema.Schema.resolve()
    |> ExJsonSchema.Validator.validate(wraft_json)
    |> case do
      :ok ->
        :ok

      {:error, error} ->
        format_errors(error)
    end
  end

  defp format_errors(error) do
    error
    |> Enum.map(fn {message, path} ->
      path
      |> String.trim_leading("#/")
      |> String.replace("/", ".")
      |> case do
        "" -> "root: #{message}"
        value -> "#{value}: #{message}"
      end
    end)
    |> then(&{:error, &1})
  end

  @doc """
  Processes a template asset by extracting and validating the contents of a ZIP file or URL, returning
  a modified parameters map with extracted data, the binary content of the ZIP, and a list of file entries.
  """
  @spec process_template_asset(map(), :file | :url, Plug.Upload.t() | String.t()) ::
          {:ok, map(), binary()} | {:error, any()}
  def process_template_asset(params, source_type, source_value) do
    with {:ok, file_binary} <- get_file_binary(source_type, source_value),
         {_, file_entries_in_zip} <- template_asset_file_list(file_binary),
         {:ok, %{"metadata" => metadata} = wraft_json} <- FileHelper.get_wraft_json(file_binary) do
      file_size =
        file_binary
        |> :erlang.byte_size()
        |> Sizeable.filesize()

      params
      |> Map.merge(metadata)
      |> Map.merge(%{
        "wraft_json" => wraft_json,
        "file_entries" => file_entries_in_zip,
        "zip_file_size" => file_size
      })
      |> then(&{:ok, &1, file_binary})
    end
  end

  @doc """
  Validates a template asset file by validating the file's contents and the ZIP file it contains.
  """
  @spec validate_template_asset_file(Plug.Upload.t()) :: :ok | {:error, String.t()}
  def validate_template_asset_file(file) do
    with true <- is_template_asset_file?(file),
         {:ok, file_binary} <- get_file_binary(:file, file),
         {folders, file_entries_in_zip} <- template_asset_file_list(file_binary),
         {:ok, _} <- template_zip_validator(file_binary, file_entries_in_zip ++ folders) do
      :ok
    end
  end

  defp is_template_asset_file?(file) do
    file
    |> FileHelper.get_global_file_type()
    |> case do
      {:ok, "template_asset"} -> true
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Invalid file type. Expected a template asset file."}
    end
  end

  defp get_file_binary_from_url(url) do
    case HTTPoison.get(url, [], follow_redirect: true) do
      {:ok, %{status_code: 200, body: binary}} ->
        {:ok, binary}

      {:ok, %{status_code: status_code}} ->
        {:error, "Failed to fetch file. Received status code: #{status_code}."}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  @doc """
  Get binary of a file.
  """
  @spec get_file_binary(:file | :url, map() | String.t()) ::
          {:ok, binary()} | {:error, String.t()}

  def get_file_binary(:url, url), do: get_file_binary_from_url(url)

  def get_file_binary(:file, %{path: file_path}) do
    file_path
    |> File.read()
    |> case do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  @doc """
  Prepare all the nessecary files and format for zip export.
  """
  def prepare_template_format(theme, layout, c_type, data_template, current_user) do
    folder_path = data_template.title
    File.mkdir_p!(folder_path)

    with :ok <-
           create_wraft_json(theme, layout, c_type, data_template, folder_path, current_user),
         :ok <- create_template_json(data_template, folder_path) do
      zip_folder(folder_path, data_template.title)
    else
      {:error, reason} ->
        File.rm_rf(folder_path)
        {:error, "Failed to prepare template: #{reason}"}
    end
  end

  def create_template_json(%{serialized: serialized} = _data_template, folder_path),
    do: File.write(folder_path <> "/template.json", Jason.encode!(serialized))

  def create_wraft_json(theme, layout, c_type, data_template, folder_path, current_user) do
    with {:ok, wraft_json} <-
           build_wraft_json(theme, layout, c_type, data_template, folder_path, current_user),
         {:ok, json} <- Jason.encode(wraft_json, pretty: true),
         :ok <-
           folder_path
           |> Path.join("wraft.json")
           |> File.write(json) do
      :ok
    else
      {:error, reason} ->
        {:error, "Failed to create wraft.json: #{reason}"}
    end
  end

  defp zip_folder(folder_path, template_name) do
    zip_path = Path.join(System.tmp_dir!(), "#{template_name}.zip")
    :zip.create(String.to_charlist(zip_path), [String.to_charlist(folder_path)])
    File.rm_rf(folder_path)
    {:ok, zip_path}
  end

  def build_wraft_json(theme, layout, c_type, data_template, file_path, current_user) do
    with {:ok, theme, fonts} <- build_theme(theme, file_path, current_user),
         {:ok, layout, layout_file, frame} <- build_layout(layout, file_path, current_user) do
      items = %{
        "theme" => theme,
        "layout" => layout,
        "variant" => build_c_type(c_type),
        "data_template" => %{
          "title" => data_template.title,
          "title_template" => data_template.title_template
        }
      }

      wraft_json = %{
        "metadata" => %{
          "name" => data_template.title,
          "description" => data_template.title_template,
          "type" => "template_asset",
          "updated_at" => Date.to_iso8601(Date.utc_today())
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "wraft.json",
              "path" => "wraft.json"
            },
            %{
              "name" => "template.json",
              "path" => "template.json"
            }
          ],
          "assets" => [layout_file],
          "fonts" => fonts
        },
        "items" => Map.merge(items, frame)
      }

      {:ok, wraft_json}
    end
  end

  defp build_theme(theme, file_path, current_user) do
    theme = Repo.preload(theme, :assets)

    {:ok,
     %{
       "name" => theme.name,
       "color" => %{
         "bodyColor" => theme.body_color,
         "primaryColor" => theme.primary_color,
         "secondaryColor" => theme.secondary_color
       }
     },
     Enum.map(theme.assets, fn %{
                                 id: asset_id,
                                 name: asset_name,
                                 file: %{file_name: asset_file_name}
                               } = _asset ->
       %{
         "fontName" => asset_name,
         "filePath" =>
           asset_file_name
           |> Path.extname()
           |> String.trim_leading(".")
           |> then(&download_file(asset_id, current_user, file_path, &1, "fonts"))
       }
     end)}
  rescue
    _ ->
      {:error, "Downloading theme files failed."}
  end

  defp build_layout(layout, file_path, current_user) do
    layout = Repo.preload(layout, [:assets, :engine, :frame])
    [%{id: asset_id, name: asset_name} = _asset | _] = layout.assets

    engine =
      case layout.engine.name do
        "Pandoc + Typst" -> "pandoc/typst"
        _ -> "pandoc/latex"
      end

    {:ok,
     %{
       "name" => layout.name,
       "slug" => layout.slug,
       "description" => layout.description,
       "engine" => engine
     },
     %{
       "name" => asset_name,
       "path" => download_file(asset_id, current_user, file_path, "pdf", "assets"),
       "type" => "layout",
       "description" => asset_name
     }, get_frame(layout, file_path)}
  rescue
    _ ->
      {:error, "Downloading layout files failed."}
  end

  defp get_frame(
         %{
           frame: %Frame{
             asset: %{id: asset_id, file: %{file_name: file_name} = _file}
           },
           organisation_id: organisation_id
         } = _layout,
         file_path
       ) do
    binary = Minio.get_object("organisations/#{organisation_id}/assets/#{asset_id}/#{file_name}")
    FileHelper.extract_file(binary, file_path)
    %{"frame" => "frame/wraft.json"}
  rescue
    _ -> %{}
  end

  defp get_frame(_, _), do: %{}

  defp build_c_type(c_type) do
    c_type = Repo.preload(c_type, [:theme, :layout, [fields: [:field_type]]])

    %{
      "name" => c_type.name,
      "description" => c_type.description,
      "prefix" => c_type.prefix,
      "type" => c_type.type,
      "color" => c_type.color,
      "fields" =>
        Enum.map(c_type.fields, fn field ->
          %{
            "name" => field.name,
            "description" => field.description,
            "type" => field.field_type.name
          }
        end)
    }
  end

  defp download_file(
         asset_id,
         %{current_org_id: org_id} = _current_user,
         file_path,
         format,
         folder_name
       ) do
    file = Minio.download("organisations/#{org_id}/assets/#{asset_id}")
    asset = Assets.get_asset(asset_id, %{current_org_id: org_id})
    path = "#{file_path}/#{folder_name}/#{asset.name}.#{format}"
    File.mkdir_p(Path.dirname(path))
    File.write!(path, file)
    "#{folder_name}/#{asset.name}.#{format}"
  end

  defp update_conflicting_name(%{"title" => title} = map, DataTemplate, current_user) do
    title
    |> unique_name(DataTemplate, current_user)
    |> then(&put_in(map, ["title"], &1))
  end

  defp update_conflicting_name(%{"name" => name} = map, type, current_user) do
    name
    |> unique_name(type, current_user)
    |> then(&put_in(map, ["name"], &1))
  end

  defp increment_name(name) do
    case Regex.run(~r/^(.*?)(\d+)$/, name, capture: :all_but_first) do
      [base, num] -> "#{String.trim(base)} #{String.to_integer(num) + 1}"
      _ -> "#{name} 2"
    end
  end

  defp unique_name(name, type, current_user) do
    name
    |> build_uniqueness_query(type, current_user)
    |> Repo.exists?()
    |> case do
      true ->
        name
        |> increment_name()
        |> unique_name(type, current_user)

      false ->
        name
    end
  end

  defp build_uniqueness_query(name, DataTemplate, current_user) do
    from(f in DataTemplate, where: f.title == ^name and f.creator_id == ^current_user.id)
  end

  defp build_uniqueness_query(name, type, current_user) do
    from(f in type,
      where: f.name == ^name and f.organisation_id == ^current_user.current_org_id
    )
  end

  defp get_rootname(path) do
    path
    |> Path.basename()
    |> Path.rootname()
  end

  @doc """
  Index of all public template assets.
  """
  @spec public_template_asset_index() :: {:ok, list()}
  def public_template_asset_index do
    query =
      from(t in TemplateAsset,
        where: is_nil(t.organisation_id) and is_nil(t.creator_id),
        order_by: [desc: t.inserted_at],
        preload: [:asset]
      )

    query
    |> Repo.all()
    |> Enum.map(fn template_asset ->
      rootname = get_rootname(template_asset.asset.file.file_name)

      %{
        id: template_asset.id,
        name: template_asset.name,
        description: template_asset.description,
        file_name: rootname,
        file_size: template_asset.zip_file_size,
        zip_file_url: Path.join(storage_url(), "public/templates/#{rootname}/#{rootname}.zip"),
        thumbnail_url: Path.join(storage_url(), "public/templates/#{rootname}/thumbnail.png")
      }
    end)
    |> then(&{:ok, &1})
  end

  defp storage_url, do: Path.join(System.get_env("MINIO_URL"), System.get_env("MINIO_BUCKET"))

  @doc """
  Download template from storage.
  """
  @spec download_public_template(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def download_public_template(template_name) do
    template_name
    |> then(&"public/templates/#{&1}/#{&1}.zip")
    |> Minio.generate_url()
    |> then(&{:ok, &1})
  end
end
