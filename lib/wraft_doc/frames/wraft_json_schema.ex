defmodule WraftDoc.Frames.WraftJsonSchema do
  @moduledoc """
  Schema for validating wraft.json frame configuration files using ex_json_schema
  """

  @doc_types %{
    "typst" => [".typ", ".typst"],
    "latex" => [".tex"]
  }

  @required_files %{
    "typst" => ["template.typst", "default.typst"],
    "latex" => ["template.tex"]
  }

  @valid_field_types [
    "string",
    "text",
    "number",
    "boolean",
    "date",
    "select",
    "multiselect"
  ]

  @output_formats ["pdf", "docx"]

  def schema do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "required" => ["version", "metadata", "packageContents", "fields", "buildSettings"],
      "properties" => %{
        "version" => %{
          "type" => "string",
          "pattern" => "^\\d+\\.\\d+\\.\\d+$",
          "description" => "Version must be in format x.y.z"
        },
        "metadata" => metadata_schema(),
        "packageContents" => package_contents_schema(),
        "fields" => %{
          "type" => "array",
          "minItems" => 1,
          "items" => field_schema()
        },
        "buildSettings" => build_settings_schema()
      }
    }
  end

  defp metadata_schema do
    %{
      "type" => "object",
      "required" => ["name", "frameType", "type"],
      "properties" => %{
        "name" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "type" => %{
          "type" => "string",
          "enum" => ["frame"],
          "description" => "Type must be 'frame'",
          "errorMessage" => "Invalid type: The 'type' field must be 'frame'."
        },
        "frameType" => %{
          "type" => "string",
          "enum" => Map.keys(@doc_types),
          "description" => "Frame type must be one of: #{Enum.join(Map.keys(@doc_types), ", ")}"
        },
        "updated_at" => %{"type" => "string"}
      }
    }
  end

  defp package_contents_schema do
    %{
      "type" => "object",
      "required" => ["rootFiles"],
      "properties" => %{
        "rootFiles" => %{
          "type" => "array",
          "minItems" => 1,
          "items" => %{
            "type" => "object",
            "required" => ["name", "path"],
            "properties" => %{
              "name" => %{"type" => "string"},
              "path" => %{"type" => "string"},
              "description" => %{"type" => "string"}
            }
          }
        },
        "assets" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["name", "path"],
            "properties" => %{
              "name" => %{"type" => "string"},
              "path" => %{"type" => "string"},
              "description" => %{"type" => "string"}
            }
          }
        },
        "fonts" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["fontName", "path"],
            "properties" => %{
              "fontName" => %{"type" => "string"},
              "fontWeight" => %{"type" => "string"},
              "path" => %{"type" => "string"},
              "required" => %{"type" => "boolean", "default" => false}
            }
          }
        }
      }
    }
  end

  defp field_schema do
    %{
      "type" => "object",
      "required" => ["type", "name"],
      "properties" => %{
        "type" => %{
          "type" => "string",
          "enum" => @valid_field_types,
          "description" => "Field type must be one of: #{Enum.join(@valid_field_types, ", ")}"
        },
        "name" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "required" => %{"type" => "boolean", "default" => false},
        "options" => %{"type" => "array", "items" => %{"type" => "string"}},
        "default" => %{"type" => "string"}
      },
      "allOf" => [
        %{
          "if" => %{
            "properties" => %{
              "type" => %{"enum" => ["select", "multiselect"]}
            },
            "required" => ["type"]
          },
          "then" => %{
            "required" => ["options"],
            "properties" => %{
              "options" => %{
                "type" => "array",
                "minItems" => 1,
                "items" => %{"type" => "string"}
              }
            }
          }
        }
      ]
    }
  end

  defp build_settings_schema do
    %{
      "type" => "object",
      "required" => ["rootFile", "outputFormat"],
      "properties" => %{
        "rootFile" => %{"type" => "string"},
        "outputFormat" => %{
          "type" => "string",
          "enum" => @output_formats,
          "description" => "Output format must be one of: #{Enum.join(@output_formats, ", ")}"
        },
        "customSettings" => %{
          "type" => "object",
          "additionalProperties" => true
        }
      }
    }
  end

  @doc """
  Validates a wraft.json document against the schema and performs custom validations
  """
  def validate(json) do
    with :ok <-
           schema() |> ExJsonSchema.Schema.resolve() |> ExJsonSchema.Validator.validate(json),
         :ok <- validate_rootfile_exists(json),
         :ok <- validate_file_extensions(json) do
      validate_required_files(json)
    end
  end

  @doc """
  Validates that the rootFile in buildSettings exists in packageContents.rootFiles
  """
  def validate_rootfile_exists(json) do
    root_file = get_in(json, ["buildSettings", "rootFile"])
    root_files = get_in(json, ["packageContents", "rootFiles"])
    root_file_paths = Enum.map(root_files || [], & &1["path"])

    if root_file in root_file_paths do
      :ok
    else
      {:error, "The rootFile '#{root_file}' in buildSettings is missing."}
    end
  end

  @doc """
  Validates that the file extensions match the frameType
  """
  def validate_file_extensions(json) do
    doc_type = get_in(json, ["metadata", "frameType"])
    root_files = get_in(json, ["packageContents", "rootFiles"]) || []
    valid_extensions = Map.get(@doc_types, doc_type, [])

    invalid_files =
      Enum.filter(root_files, fn file ->
        path = file["path"]
        not Enum.any?(valid_extensions, &String.ends_with?(path, &1))
      end)

    if Enum.empty?(invalid_files) do
      :ok
    else
      file_names = Enum.map_join(invalid_files, ", ", & &1["name"])

      {:error,
       "Files (#{file_names}) must have one of these extensions: #{Enum.join(valid_extensions, ", ")}"}
    end
  end

  @doc """
  Validates that required files for the frameType exist
  """
  def validate_required_files(json) do
    doc_type = get_in(json, ["metadata", "frameType"])
    root_files = get_in(json, ["packageContents", "rootFiles"]) || []

    required_files = Map.get(@required_files, doc_type, [])
    root_file_paths = Enum.map(root_files, & &1["path"])

    missing_files =
      Enum.filter(required_files, fn required_file ->
        not Enum.any?(root_file_paths, &String.ends_with?(&1, required_file))
      end)

    if Enum.empty?(missing_files) do
      :ok
    else
      {:error, "Required files missing for #{doc_type}: #{Enum.join(missing_files, ", ")}"}
    end
  end

  @doc """
  Format validation errors into a readable message
  """
  def format_errors({:error, errors}) when is_list(errors) do
    Enum.map_join(errors, "; ", fn
      %{error: error, path: path} ->
        path_string = Enum.join(path, ".")
        "#{path_string}: #{to_string(error)}"

      error when is_binary(error) ->
        error
    end)
  end

  def format_errors({:error, error}) when is_binary(error), do: error
  def format_errors(:ok), do: nil
end

defmodule WraftDoc.Frames.WraftJson.Metadata do
  @moduledoc """
  Schema for validating wraft.json metadata
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @doc_types %{
    "typst" => [".typ", ".typst"],
    "latex" => [".tex"]
  }

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:type, :string)
    field(:frameType, :string)
    field(:updated_at, :string)
  end

  def changeset(struct \\ %Metadata{}, params) do
    struct
    |> cast(params, [:name, :description, :type, :frameType, :updated_at])
    |> validate_required([:name, :frameType, :type])
    |> validate_inclusion(:type, ["frame"])
    |> validate_inclusion(:frameType, Map.keys(@doc_types),
      message: "must be one of: #{Enum.join(Map.keys(@doc_types), ", ")}"
    )
  end
end
