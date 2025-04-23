defmodule WraftDoc.TemplateAssets.WraftJsonSchema do
  @moduledoc """
  Schema for template asset wraft.json
  """

  def schema do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "required" => ["metadata", "packageContents", "items"],
      "properties" => %{
        "metadata" => %{
          "type" => "object",
          "required" => ["name", "description", "type", "updated_at"],
          "properties" => %{
            "name" => %{"type" => "string"},
            "description" => %{"type" => "string"},
            "type" => %{"type" => "string"},
            "updated_at" => %{"type" => "string", "format" => "date"}
          }
        },
        "packageContents" => %{
          "type" => "object",
          "required" => ["rootFiles", "assets", "fonts"],
          "properties" => %{
            "rootFiles" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "required" => ["name", "path"],
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "path" => %{"type" => "string"}
                }
              }
            },
            "assets" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "required" => ["name", "path", "type", "description"],
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "path" => %{"type" => "string"},
                  "type" => %{"type" => "string"},
                  "description" => %{"type" => "string"}
                }
              }
            },
            "fonts" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "required" => ["fontName", "fontWeight", "path"],
                "properties" => %{
                  "fontName" => %{"type" => "string"},
                  "fontWeight" => %{"type" => "string"},
                  "path" => %{"type" => "string"},
                  "required" => %{"type" => "boolean"}
                }
              }
            }
          }
        },
        "items" => %{
          "type" => "object",
          "properties" => %{
            "theme" => %{
              "type" => "object",
              "required" => ["name", "colors"],
              "properties" => %{
                "name" => %{"type" => "string"},
                "colors" => %{
                  "type" => "object",
                  "required" => ["primaryColor", "secondaryColor", "bodyColor"],
                  "properties" => %{
                    "primaryColor" => %{"type" => "string", "pattern" => "^#[0-9A-Fa-f]{6}$"},
                    "secondaryColor" => %{"type" => "string", "pattern" => "^#[0-9A-Fa-f]{6}$"},
                    "bodyColor" => %{"type" => "string", "pattern" => "^#[0-9A-Fa-f]{6}$"}
                  }
                }
              }
            },
            "layout" => %{
              "type" => "object",
              "required" => ["slug", "meta", "name", "description", "engine"],
              "properties" => %{
                "slug" => %{"type" => "string"},
                "meta" => %{
                  "type" => "object",
                  "required" => ["standard_size", "margin"],
                  "properties" => %{
                    "standard_size" => %{"type" => "string"},
                    "margin" => %{"type" => "string"}
                  }
                },
                "description" => %{"type" => "string"},
                "engine" => %{"type" => "string"}
              }
            },
            "flow" => %{
              "type" => "object",
              "required" => ["name"],
              "properties" => %{
                "name" => %{"type" => "string"}
              }
            },
            "variant" => %{
              "type" => "object",
              "required" => ["color", "name", "description", "fields"],
              "properties" => %{
                "color" => %{"type" => "string", "pattern" => "^#[0-9A-Fa-f]{3,6}$"},
                "name" => %{"type" => "string"},
                "description" => %{"type" => "string"},
                "fields" => %{
                  "type" => "array",
                  "items" => %{
                    "type" => "object",
                    "required" => ["type", "name", "description"],
                    "properties" => %{
                      "type" => %{
                        "type" => "string",
                        "enum" => ["string", "date", "number", "boolean"]
                      },
                      "name" => %{"type" => "string"},
                      "description" => %{"type" => "string"},
                      "required" => %{"type" => "boolean"}
                    }
                  }
                }
              }
            },
            "data_template" => %{
              "type" => "object",
              "required" => ["title", "title_template"],
              "properties" => %{
                "title" => %{"type" => "string"},
                "title_template" => %{"type" => "string"}
              }
            }
          }
        }
      }
    }
  end
end

defmodule WraftDoc.TemplateAssets.Metadata do
  @moduledoc """
  Schema for validating wraft.json metadata
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:type, :string)
    field(:updated_at, :string)
  end

  def changeset(struct \\ %Metadata{}, params) do
    struct
    |> cast(params, [:name, :description, :type, :updated_at])
    |> validate_required([:name, :description, :type])
    |> validate_inclusion(:type, ["template_asset"])
  end
end
