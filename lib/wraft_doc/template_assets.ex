defmodule WraftDoc.TemplateAssets do
  @moduledoc """
  Context module for Template Assets.
  """

  import Ecto
  import Ecto.Query

  require Logger

  alias Ecto.Multi
  alias WraftDoc.Client.Minio
  alias WraftDoc.Document
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.DataTemplate
  alias WraftDoc.Document.Engine
  alias WraftDoc.Document.FieldType
  alias WraftDoc.Document.Layout
  alias WraftDoc.Document.Theme
  alias WraftDoc.Enterprise
  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDoc.TemplateAssets.WraftJson

  @internal_file "wraft.json"
  @allowed_folders ["theme", "layout", "contract"]
  @allowed_files ["template.json", "wraft.json"]
  @font_style_name ~w(Regular Italic Bold BoldItalic)

  @doc """
  Create a template asset.
  """
  # TODO - write test
  @spec create_template_asset(User.t(), map()) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t()}
  def create_template_asset(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    Multi.new()
    |> Multi.insert(
      :template_asset,
      current_user |> build_assoc(:template_assets) |> TemplateAsset.changeset(params)
    )
    |> Multi.update(
      :template_asset_file_upload,
      &TemplateAsset.file_changeset(&1.template_asset, params)
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{template_asset_file_upload: template_asset}} -> {:ok, template_asset}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def create_template_asset(_, _), do: {:error, :fake}

  @doc """
  Index of all template assets in an organisation.
  """
  # TODO - Write tests
  @spec template_asset_index(User.t(), map()) :: map()
  def template_asset_index(%{current_org_id: organisation_id}, params) do
    query =
      from(a in TemplateAsset,
        where: a.organisation_id == ^organisation_id,
        order_by: [desc: a.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def template_asset_index(_, _), do: {:error, :fake}

  @doc """
  Show a template asset.
  """
  # TODO - write tests
  @spec show_template_asset(binary(), User.t()) :: TemplateAsset.t() | {:error, atom()}
  def show_template_asset(<<_::288>> = template_asset_id, user) do
    template_asset_id
    |> get_template_asset(user)
    |> Repo.preload([:creator])
  end

  @doc """
  Get a template asset from its UUID.
  """
  # TODO - Write tests
  @spec get_template_asset(binary(), User.t()) :: TemplateAsset.t() | {:error, atom()}
  def get_template_asset(<<_::288>> = id, %{current_org_id: org_id}),
    do: Repo.get_by(TemplateAsset, id: id, organisation_id: org_id)

  @doc """
  Update a template asset.
  """
  # TODO - Write tests
  @spec update_template_asset(TemplateAsset.t(), map()) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t()}
  def update_template_asset(template_asset, params) do
    template_asset |> TemplateAsset.update_changeset(params) |> Repo.update()
  end

  @doc """
  Delete a template asset.
  """
  # TODO - Write tests
  @spec delete_template_asset(TemplateAsset.t()) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t()}
  def delete_template_asset(%TemplateAsset{organisation_id: org_id} = template_asset) do
    # Delete the template asset file
    Minio.delete_file("organisations/#{org_id}/template_assets/#{template_asset.id}")

    Repo.delete(template_asset)
  end

  @doc """
  Update wraft_json into template asset table.
  """
  @spec update_template_asset_json(TemplateAsset.t(), map()) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t()}
  def update_template_asset_json(%TemplateAsset{} = template_asset, attrs) do
    template_asset
    |> TemplateAsset.update_wraft_json_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Imports template asset.
  """
  @spec import_template(User.t(), binary()) ::
          DataTemplate.t() | {:error, any()}
  def import_template(current_user, downloaded_zip_binary) do
    case get_wraft_json_map(downloaded_zip_binary) do
      {:ok, template_map} ->
        prepare_template(template_map, current_user, downloaded_zip_binary)
    end
  end

  @doc """
  Download zip file from minio as binary.
  """
  @spec download_zip_from_minio(User.t(), Ecto.UUID.t()) :: {:error, any()} | {:ok, binary()}
  def download_zip_from_minio(current_user, template_asset_id) do
    downloaded_zip_binary =
      Minio.download(
        "organisations/#{current_user.current_org_id}/template_assets/#{template_asset_id}"
      )

    {:ok, downloaded_zip_binary}
  rescue
    error -> {:error, error.message}
  end

  @doc """
  Gets wraft json map.
  """
  @spec get_wraft_json_map(binary()) :: {:ok, map()}
  def get_wraft_json_map(downloaded_zip_binary) do
    {:ok, wraft_json} = load_json_file(downloaded_zip_binary)
    Jason.decode(wraft_json)
  end

  @doc """
  Gets the list of specific items in template asset
  """
  @spec template_asset_file_list(binary()) :: {:ok, [String.t()]} | {:error, any()}
  def template_asset_file_list(zip_binary) do
    case get_zip_entries(zip_binary) do
      {:ok, entries} ->
        entries
        |> Enum.map(& &1.file_name)
        |> Enum.filter(fn file_name ->
          Enum.any?(@allowed_folders, &String.starts_with?(file_name, "#{&1}/")) ||
            file_name in @allowed_files
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Prepares template by taking Wraft_json map, current user and zip binary.
  """
  @spec prepare_template(map(), User.t(), binary()) :: {:ok, any()} | {:error, any()}
  def prepare_template(template_map, current_user, downloaded_file) do
    case prepare_template_transaction(template_map, current_user, downloaded_file) do
      {:ok, %{data_template: data_template}} ->
        Logger.info("Theme, Layout, Flow, variant created successfully.")
        {:ok, data_template}

      {:error, _failed_operation, error, _changes_so_far} ->
        Logger.error("Failed to process. Error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp prepare_template_transaction(template_map, current_user, downloaded_file) do
    Multi.new()
    |> Multi.run(:theme, fn _repo, _changes ->
      prepare_theme(template_map["theme"], current_user, downloaded_file)
    end)
    |> Multi.run(:flow, fn _repo, _changes ->
      Enterprise.create_flow(current_user, template_map["flow"])
    end)
    |> Multi.run(:layout, fn _repo, _changes ->
      prepare_layout(template_map["layout"], downloaded_file, current_user)
    end)
    |> Multi.run(:content_type, fn _repo, %{theme: theme, flow: flow, layout: layout} ->
      prepare_content_type(template_map["variant"], current_user, theme.id, layout.id, flow.id)
    end)
    |> Multi.run(:data_template, fn _repo, %{content_type: content_type} ->
      prepare_data_template(
        current_user,
        template_map["data_template"],
        downloaded_file,
        content_type
      )
    end)
    |> Repo.transaction()
  end

  defp get_engine(engine) do
    # TODO multiple engines selection
    [engine1, _engine2] = String.split(engine, "/")

    case Repo.get_by(Engine, name: String.capitalize(engine1)) do
      nil -> Logger.warning("No engine found with the name #{engine1}")
      engine -> engine.id
    end
  end

  defp prepare_theme(theme, current_user, downloaded_file) do
    with {:ok, entries} <- get_zip_entries(downloaded_file),
         asset_ids <- prepare_theme_assets(entries, downloaded_file, current_user),
         params <- prepare_theme_attrs(theme, asset_ids),
         %Theme{} = theme <- Document.create_theme(current_user, params) do
      {:ok, theme}
    end
  end

  defp prepare_theme_assets(entries, downloaded_file, current_user) do
    entries
    |> get_theme_font_file_entries()
    |> extract_and_save_fonts(downloaded_file, current_user)
  end

  defp prepare_theme_attrs(%{"name" => name, "colors" => colors}, asset_ids) do
    Map.merge(colors, %{
      "name" => name,
      "font" => name,
      "primary_color" => colors["primaryColor"],
      "secondary_color" => colors["secondaryColor"],
      "body_color" => colors["bodyColor"],
      "assets" => asset_ids
    })
  end

  defp get_theme_font_file_entries(entries) do
    Enum.filter(entries, fn entry ->
      case Regex.run(~r/^theme\/.*-(?<style>\w+)\.otf$/i, entry.file_name) do
        [_, style] when style in @font_style_name -> true
        _ -> false
      end
    end)
  end

  defp extract_and_save_fonts(entries, downloaded_zip_file, current_user) do
    entries
    |> Task.async_stream(&process_entry(&1, downloaded_zip_file, current_user), timeout: :infinity)
    |> Enum.map(fn
      {:ok, {:ok, asset_id}} -> asset_id
      {:ok, {:error, _reason}} -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(",")
  end

  defp process_entry(entry, downloaded_zip_file, current_user) do
    with {:ok, content} <- extract_file_content(downloaded_zip_file, entry.file_name),
         {:ok, temp_file_path} <- write_temp_file(content),
         asset_params = prepare_theme_asset_params(entry, temp_file_path, current_user),
         {:ok, asset} <- WraftDoc.Document.create_asset(current_user, asset_params) do
      {:ok, asset.id}
    else
      error ->
        Logger.error("""
        Failed to process entry: #{inspect(entry.file_name)}.
        Error: #{inspect(error)}.
        """)

        {:error, error}
    end
  end

  defp write_temp_file(content) do
    temp_file_path = Briefly.create!()
    File.write(temp_file_path, content)
    {:ok, temp_file_path}
  end

  defp prepare_theme_asset_params(entry, temp_file_path, current_user) do
    %{
      "name" => Path.basename(entry.file_name),
      "type" => "theme",
      "file" => %Plug.Upload{
        filename: Path.basename(entry.file_name),
        content_type: get_file_type(entry.file_name),
        path: temp_file_path
      },
      "creator_id" => current_user.id
    }
  end

  defp get_file_type(filename) do
    case Path.extname(filename) do
      ".otf" -> "font/otf"
      ".ttf" -> "font/ttf"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end

  defp prepare_layout(layouts, downloaded_file, current_user) do
    # filter engine name
    engine_id = get_engine(layouts["engine"])

    with {:ok, entries} <- get_zip_entries(downloaded_file),
         asset_id <- prepare_layout_assets(entries, downloaded_file, current_user),
         params <- prepare_layout_attrs(layouts, engine_id, asset_id),
         %Engine{} = engine <- Document.get_engine(params["engine_id"]),
         %Layout{} = layout <- Document.create_layout(current_user, engine, params) do
      {:ok, layout}
    end
  end

  defp prepare_layout_assets(entries, downloaded_file, current_user) do
    entries
    |> get_layout_file_entries()
    |> extract_and_prepare_layout_asset(downloaded_file, current_user)
  end

  defp prepare_layout_attrs(layout, engine_id, asset_id) do
    %{
      "name" => layout["name"],
      "meta" => layout["meta"],
      "description" => layout["description"],
      "slug" => layout["slug"],
      "engine_id" => engine_id,
      "assets" => asset_id,
      "width" => 40,
      "height" => 40,
      "unit" => "cm"
    }
  end

  defp get_layout_file_entries(entries) do
    Enum.filter(entries, fn entry ->
      entry.file_name =~ ~r/^layout\/.*\.pdf$/i
    end)
  end

  defp extract_and_prepare_layout_asset(entries, downloaded_zip_file, current_user) do
    entry = List.first(entries)

    with {:ok, content} <- extract_file_content(downloaded_zip_file, entry.file_name),
         temp_file_path <- Briefly.create!(),
         :ok <- File.write(temp_file_path, content),
         asset_params <- prepare_layout_asset_params(entry, temp_file_path, current_user),
         {:ok, asset} <- WraftDoc.Document.create_asset(current_user, asset_params) do
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
         %ContentType{} = content_type <- Document.create_content_type(current_user, params) do
      {:ok, content_type}
    end
  end

  defp prepare_content_type_attrs(
         %{
           "name" => name,
           "description" => description,
           "color" => color,
           "prefix" => prefix
         } = content_type,
         current_user,
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
      "layout_id" => layout_id,
      "flow_id" => flow_id,
      "theme_id" => theme_id,
      "fields" => fields,
      "organisation_id" => current_user.current_org_id,
      "creator_id" => current_user.id
    }
  end

  defp prepare_data_template(current_user, template_map, downloaded_file, content_type) do
    with params <- prepare_data_template_attrs(template_map, downloaded_file, content_type.id),
         {:ok, %DataTemplate{} = data_template} <-
           Document.create_data_template(current_user, content_type, params) do
      {:ok, data_template}
    end
  end

  defp prepare_data_template_attrs(template_map, downloaded_file, content_type_id) do
    with procemirror_json <- get_data_template_procemirror(downloaded_file),
         {:ok, json_data} <- extract_file_content(downloaded_file, procemirror_json),
         decoded_data <- Jason.decode!(json_data),
         serialized_prosemirror_data <- decoded_data["data"] do
      markdown_data =
        serialized_prosemirror_data
        |> Jason.decode!()
        |> WraftDoc.ProsemirrorToMarkdown.convert()

      %{
        "c_type_id" => content_type_id,
        "title" => template_map["title"],
        "title_template" => template_map["title_template"],
        "data" => markdown_data,
        "serialized" => %{"data" => serialized_prosemirror_data}
      }
    end
  end

  # Not using now for future use
  # defp get_data_template_md(downloaded_file) do
  #   case get_zip_entries(downloaded_file) do
  #     {:ok, entries} ->
  #       template_md = Enum.find(entries, fn entry -> entry.file_name =~ ~r/^.*\.md$/i end)
  #       template_md.file_name
  #     _ ->
  #       Logger.error(" template data not found")
  #   end
  # end

  defp get_data_template_procemirror(downloaded_file) do
    case get_zip_entries(downloaded_file) do
      {:ok, entries} ->
        procemirror_json =
          Enum.find(entries, fn entry -> entry.file_name =~ ~r/template\.json$/i end)

        procemirror_json.file_name

      _ ->
        Logger.error("template_json not found")
    end
  end

  defp extract_file_content(zip_file_binary, file_name) do
    {:ok, unzip} = Unzip.new(zip_file_binary)
    unzip_stream = Unzip.file_stream!(unzip, file_name)

    file_content =
      unzip_stream
      |> Enum.into([], fn chunk -> chunk end)
      |> IO.iodata_to_binary()
      |> String.trim()

    case file_content do
      "" -> {:error, "File content is empty"}
      _ -> {:ok, file_content}
    end
  end

  @spec get_zip_entries(binary()) :: {:error, any()} | {:ok, [Unzip.Entry.t()]}
  def get_zip_entries(zip_binary) do
    with {:ok, unzip} <- Unzip.new(zip_binary),
         entries <- Unzip.list_entries(unzip) do
      {:ok, entries}
    else
      _ ->
        {:error, "Invalid ZIP entries."}
    end
  end

  defp load_json_file(file_binary) do
    {:ok, unzip} = Unzip.new(file_binary)
    internal_file = @internal_file
    unzip_stream = Unzip.file_stream!(unzip, internal_file)

    file_content =
      unzip_stream
      |> Enum.into([], fn chunk -> chunk end)
      |> IO.iodata_to_binary()
      |> String.trim()

    {:ok, file_content}
  end

  @doc """
  Validates the contents of a ZIP file uploaded via Waffle.
  """
  @spec template_zip_validator(Waffle.File.t()) :: :ok | {:error, any()}
  def template_zip_validator(file) do
    with {:ok, zip_binary} <- read_zip_contents(file.path),
         file_entries_in_zip <- template_asset_file_list(zip_binary),
         true <- validate_zip_entries(file_entries_in_zip),
         {:ok, wraft_json} <- extract_file_content(zip_binary, "wraft.json"),
         wraft_json_map <- Jason.decode!(wraft_json),
         true <- validate_wraft_json(wraft_json_map) do
      :ok
    else
      {:error, error} ->
        {:error, error}

      {:error, :invalid_zip} ->
        {:error, "Invalid ZIP file."}
    end
  end

  defp read_zip_contents(file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        {:ok, binary}

      _ ->
        {:error, :invalid_zip}
    end
  end

  defp validate_wraft_json(wraft_json) do
    %WraftJson{}
    |> WraftJson.changeset(wraft_json)
    |> case do
      %{valid?: true} -> true
      %{valid?: false} = changeset -> {:error, extract_errors(changeset)}
    end
  end

  defp extract_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, messages} ->
      "#{field}: #{Enum.join(messages, ", ")}"
    end)
  end

  defp validate_zip_entries(entries) do
    folders_in_zip = extract_folders(entries)
    files_in_zip = extract_files(entries)
    missing_folders = @allowed_folders -- folders_in_zip
    missing_files = @allowed_files -- files_in_zip

    case {missing_folders, missing_files} do
      {[], []} ->
        true

      _ ->
        missing_items = Enum.concat(missing_folders, missing_files)
        {:error, "Required items not found in this zip file: #{Enum.join(missing_items, ", ")}"}
    end
  end

  defp extract_folders(entries) do
    entries
    |> Enum.filter(&String.ends_with?(&1, "/"))
    |> Enum.map(&String.trim_trailing(&1, "/"))
  end

  defp extract_files(entries) do
    Enum.filter(entries, &(!String.ends_with?(&1, "/")))
  end
end
