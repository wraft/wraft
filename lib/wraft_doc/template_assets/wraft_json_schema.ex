defmodule WraftDoc.TemplateAssets.WraftJsonSchema do
  @moduledoc """
  Schema for template asset wraft.json
  """

  def schema do
    %{
      "properties" => %{
        "data_template" => %{
          "additionalProperties" => false,
          "properties" => %{
            "title" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "title_template" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            }
          },
          "required" => ["title", "title_template"],
          "type" => "object"
        },
        "flow" => %{
          "additionalProperties" => false,
          "properties" => %{
            "name" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            }
          },
          "required" => ["name"],
          "type" => "object"
        },
        "layout" => %{
          "additionalProperties" => false,
          "properties" => %{
            "description" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "engine" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "meta" => %{
              "additionalProperties" => false,
              "properties" => %{
                "margin" => %{
                  "minLength" => 0,
                  "pattern" => "^.*$",
                  "type" => "string"
                },
                "standard_size" => %{
                  "minLength" => 0,
                  "pattern" => "^.*$",
                  "type" => "string"
                }
              },
              "required" => ["margin", "standard_size"],
              "type" => "object"
            },
            "name" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "slug" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "slug_file" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            }
          },
          "required" => ["description", "engine", "meta", "name", "slug", "slug_file"],
          "type" => "object"
        },
        "theme" => %{
          "additionalProperties" => false,
          "properties" => %{
            "colors" => %{
              "additionalProperties" => false,
              "properties" => %{
                "bodyColor" => %{
                  "minLength" => 0,
                  "pattern" => "^.*$",
                  "type" => "string"
                },
                "primaryColor" => %{
                  "minLength" => 0,
                  "pattern" => "^.*$",
                  "type" => "string"
                },
                "secondaryColor" => %{
                  "minLength" => 0,
                  "pattern" => "^.*$",
                  "type" => "string"
                }
              },
              "required" => ["bodyColor", "primaryColor", "secondaryColor"],
              "type" => "object"
            },
            "name" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            }
          },
          "required" => ["colors", "name"],
          "type" => "object"
        },
        "variant" => %{
          "additionalProperties" => true,
          "properties" => %{
            "color" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "description" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "fields" => %{
              "items" => %{
                "additionalProperties" => true,
                "properties" => %{
                  "description" => %{
                    "minLength" => 0,
                    "pattern" => "^.*$",
                    "type" => "string"
                  },
                  "name" => %{
                    "minLength" => 0,
                    "pattern" => "^.*$",
                    "type" => "string"
                  },
                  "required" => %{"type" => "boolean"},
                  "type" => %{
                    "minLength" => 0,
                    "pattern" => "^.*$",
                    "type" => "string"
                  }
                },
                "required" => ["description", "name", "required", "type"],
                "type" => "object"
              },
              "type" => "array"
            },
            "name" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            },
            "prefix" => %{
              "minLength" => 0,
              "pattern" => "^.*$",
              "type" => "string"
            }
          },
          "required" => ["color", "description", "fields", "name", "prefix"],
          "type" => "object"
        }
      },
      "type" => "object"
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
