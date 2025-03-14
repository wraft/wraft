defmodule WraftDoc.Frames.WraftJson do
  @moduledoc """
  Schema for validating wraft.json frame configuration files with flexible validation
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias __MODULE__.BuildSettings
  alias __MODULE__.Field
  alias __MODULE__.Metadata
  alias __MODULE__.PackageContents

  @doc_types %{
    "typst" => [".typ", ".typst"],
    "latex" => [".tex"]
  }

  @required_files %{
    "typst" => ["template.typst", "default.typst"],
    "latex" => ["template.tex"]
  }

  @primary_key false
  embedded_schema do
    field(:version, :string)
    embeds_one(:metadata, Metadata)
    embeds_one(:packageContents, PackageContents)
    embeds_many(:fields, Field)
    embeds_one(:buildSettings, BuildSettings)
  end

  def doc_types, do: @doc_types
  def required_files, do: @required_files

  def changeset(struct \\ %WraftJson{}, params) do
    struct
    |> cast(params, [:version])
    |> validate_required([:version])
    |> validate_format(:version, ~r/^\d+\.\d+\.\d+$/, message: "must be in format x.y.z")
    |> cast_embed(:metadata, required: true)
    |> cast_embed(:packageContents, required: true)
    |> cast_embed(:fields, required: true)
    |> cast_embed(:buildSettings, required: true)
    |> validate_rootfile_exists()
    |> validate_file_extensions()
    |> validate_required_files()
  end

  defp validate_rootfile_exists(changeset) do
    with %{valid?: true} <- changeset,
         build_settings <- get_field(changeset, :buildSettings),
         package_contents <- get_field(changeset, :packageContents),
         %{rootFile: root_file} <- build_settings,
         root_files <- Enum.map(package_contents.rootFiles, & &1.path) do
      if root_file in root_files do
        changeset
      else
        add_error(
          changeset,
          :buildSettings,
          "rootFile must reference a file defined in packageContents.rootFiles"
        )
      end
    else
      _ -> changeset
    end
  end

  defp validate_file_extensions(changeset) do
    with %{valid?: true} <- changeset,
         metadata <- get_field(changeset, :metadata),
         %{type: doc_type} <- metadata,
         valid_extensions <- Map.get(@doc_types, doc_type, []),
         package_contents <- get_field(changeset, :packageContents),
         root_files <- package_contents.rootFiles do
      invalid_files =
        Enum.filter(root_files, fn file ->
          path = file.path
          not Enum.any?(valid_extensions, &String.ends_with?(path, &1))
        end)

      if Enum.empty?(invalid_files) do
        changeset
      else
        file_names = Enum.map_join(invalid_files, ", ", & &1.name)

        add_error(
          changeset,
          :packageContents,
          "Files (#{file_names}) must have one of these extensions: #{Enum.join(valid_extensions, ", ")}"
        )
      end
    else
      _ -> changeset
    end
  end

  defp validate_required_files(changeset) do
    with %{valid?: true} <- changeset,
         metadata <- get_field(changeset, :metadata),
         %{type: doc_type} <- metadata,
         required_files <- Map.get(@required_files, doc_type, []),
         package_contents <- get_field(changeset, :packageContents),
         root_files <- Enum.map(package_contents.rootFiles, & &1.path) do
      missing_files =
        Enum.filter(required_files, fn required_file ->
          not Enum.any?(root_files, &String.ends_with?(&1, required_file))
        end)

      if Enum.empty?(missing_files) do
        changeset
      else
        add_error(
          changeset,
          :packageContents,
          "Required files missing for #{doc_type}: #{Enum.join(missing_files, ", ")}"
        )
      end
    else
      _ -> changeset
    end
  end

  @doc """
  Creates a changeset from wraft.json data and validates it
  """
  def validate_json(json_data) do
    changeset = changeset(%WraftJson{}, json_data)

    case changeset.valid? do
      true -> :ok
      false -> {:error, "Invalid wraft_json"}
    end
  end
end

defmodule WraftDoc.Frames.WraftJson.Metadata do
  @moduledoc """
  Schema for validating wraft.json metadata
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias WraftDoc.Frames.WraftJson

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:type, :string)
    field(:lastUpdated, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :description, :type, :lastUpdated])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, Map.keys(WraftJson.doc_types()),
      message:
        "must be one of: #{Enum.join(Map.keys(WraftDoc.Frames.WraftJson.doc_types()), ", ")}"
    )
  end
end

defmodule WraftDoc.Frames.WraftJson.Field do
  @moduledoc """
  Schema for validating wraft.json fields
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_field_types [
    "string",
    "text",
    "number",
    "boolean",
    "date",
    "select",
    "multiselect"
  ]

  @primary_key false
  embedded_schema do
    field(:type, :string)
    field(:name, :string)
    field(:description, :string)
    field(:required, :boolean, default: false)
    field(:options, {:array, :string})
    field(:default, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:type, :name, :description, :required, :options, :default])
    |> validate_required([:type, :name])
    |> validate_inclusion(:type, @valid_field_types,
      message: "must be one of: #{Enum.join(@valid_field_types, ", ")}"
    )
    |> validate_select_options()
  end

  defp validate_select_options(changeset) do
    with type when type in ["select", "multiselect"] <- get_field(changeset, :type),
         options when is_nil(options) or options == [] <- get_field(changeset, :options) do
      add_error(changeset, :options, "must be provided for select/multiselect fields")
    else
      _ -> changeset
    end
  end
end

defmodule WraftDoc.Frames.WraftJson.BuildSettings do
  @moduledoc """
  Schema for validating wraft.json build settings
  """
  use Ecto.Schema
  import Ecto.Changeset

  @output_formats ["pdf", "docx"]

  @primary_key false
  embedded_schema do
    field(:rootFile, :string)
    field(:outputFormat, :string)
    # Flexible map for custom build settings
    field(:customSettings, :map, default: %{})
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:rootFile, :outputFormat, :customSettings])
    |> validate_required([:rootFile, :outputFormat])
    |> validate_inclusion(:outputFormat, @output_formats,
      message: "must be one of: #{Enum.join(@output_formats, ", ")}"
    )
  end
end

defmodule WraftDoc.Frames.WraftJson.PackageContents do
  @moduledoc """
  Schema for validating wraft.json package contents
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.Asset
  alias __MODULE__.Font
  alias __MODULE__.RootFile

  @primary_key false
  embedded_schema do
    embeds_many(:rootFiles, RootFile)
    embeds_many(:assets, Asset)
    embeds_many(:fonts, Font)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:rootFiles, required: true)
    |> cast_embed(:assets, required: false)
    |> cast_embed(:fonts, required: false)
    |> validate_root_files()
  end

  defp validate_root_files(changeset) do
    root_files = get_field(changeset, :rootFiles, [])

    if Enum.empty?(root_files) do
      add_error(changeset, :rootFiles, "must contain at least one root file")
    else
      changeset
    end
  end
end

defmodule WraftDoc.Frames.WraftJson.PackageContents.RootFile do
  @moduledoc """
  Schema for validating wraft.json package contents root files
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:path, :string)
    field(:description, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :path, :description])
    |> validate_required([:name, :path])
  end
end

defmodule WraftDoc.Frames.WraftJson.PackageContents.Asset do
  @moduledoc """
  Schema for validating wraft.json package contents assets
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:path, :string)
    field(:description, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :path, :description])
    |> validate_required([:name, :path])
  end
end

defmodule WraftDoc.Frames.WraftJson.PackageContents.Font do
  @moduledoc """
  Schema for validating wraft.json package contents fonts
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:fontName, :string)
    field(:fontWeight, :string)
    field(:path, :string)
    field(:required, :boolean, default: false)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:fontName, :fontWeight, :path, :required])
    |> validate_required([:fontName, :path])
  end
end
