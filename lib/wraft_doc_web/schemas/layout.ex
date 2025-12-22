defmodule WraftDocWeb.Schemas.Layout do
  @moduledoc """
  Schema for Layout request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Layout do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Layout",
      description: "A Layout",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the layout"},
        name: %Schema{type: :string, description: "Layout's name"},
        description: %Schema{type: :string, description: "Layout's description"},
        width: %Schema{type: :number, format: :float, description: "Width of the layout"},
        height: %Schema{type: :number, format: :float, description: "Height of the layout"},
        unit: %Schema{type: :string, description: "Unit of dimensions"},
        slug: %Schema{type: :string, description: "Name of the slug to be used for the layout"},
        frame_id: %Schema{type: :string, description: "The ID of the layout"},
        screenshot: %Schema{type: :string, description: "URL of the uploaded screenshot"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the layout created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the layout last updated",
          format: "ISO-8601"
        }
      },
      required: [:id, :name],
      example: %{
        id: "1232148nb3478",
        name: "Official Letter",
        description: "An official letter",
        width: 40.0,
        height: 20.0,
        unit: "cm",
        slug: "Pandoc",
        frame: %{
          id: "123e4567-e89b-12d3-a456-426614174000",
          name: "my-document-frame",
          frame: %{
            file_name: "template.tex",
            updated_at: "2024-11-29T12:56:47"
          },
          inserted_at: "2024-01-15T10:30:00Z",
          updated_at: "2024-01-15T10:30:00Z"
        },
        screenshot: "/official_letter.jpg",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule LayoutAndEngine do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Layout and Engine",
      description: "Layout to be used for the generation of a document.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the layout"},
        name: %Schema{type: :string, description: "Layout's name"},
        description: %Schema{type: :string, description: "Layout's description"},
        width: %Schema{type: :number, format: :float, description: "Width of the layout"},
        height: %Schema{type: :number, format: :float, description: "Height of the layout"},
        unit: %Schema{type: :string, description: "Unit of dimensions"},
        slug: %Schema{type: :string, description: "Name of the slug to be used for the layout"},
        frame_id: %Schema{type: :string, description: "The ID of the layout"},
        screenshot: %Schema{type: :string, description: "URL of the uploaded screenshot"},
        engine: WraftDocWeb.Schemas.Engine.Engine,
        assets: %Schema{
          type: :array,
          items: WraftDocWeb.Schemas.Asset.Asset,
          description: "Assets"
        },
        inserted_at: %Schema{
          type: :string,
          description: "When was the layout created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the layout last updated",
          format: "ISO-8601"
        }
      },
      required: [:id, :name],
      example: %{
        id: "1232148nb3478",
        name: "Official Letter",
        description: "An official letter",
        width: 40.0,
        height: 20.0,
        unit: "cm",
        slug: "Pandoc",
        screenshot: "/official_letter.jpg",
        frame: %{
          id: "123e4567-e89b-12d3-a456-426614174000",
          name: "my-document-frame",
          frame: %{
            file_name: "template.tex",
            updated_at: "2024-11-29T12:56:47"
          },
          inserted_at: "2024-01-15T10:30:00Z",
          updated_at: "2024-01-15T10:30:00Z"
        },
        engine: %{
          id: "1232148nb3478",
          name: "Pandoc",
          api_route: "",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        assets: [
          %{
            id: "1232148nb3478",
            name: "Asset",
            file: "/signature.pdf",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule LayoutsAndEngines do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Layouts and its Engines",
      description: "All layouts that have been created and their engines",
      type: :array,
      items: LayoutAndEngine
    })
  end

  defmodule ShowLayout do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Layout and all its details",
      description: "API to show a layout and all its details",
      type: :object,
      properties: %{
        layout: LayoutAndEngine,
        creator: WraftDocWeb.Schemas.User.User
      },
      example: %{
        layout: %{
          id: "1232148nb3478",
          name: "Official Letter",
          description: "An official letter",
          width: 40.0,
          height: 20.0,
          unit: "cm",
          slug: "Pandoc",
          screenshot: "/official_letter.jpg",
          frame: %{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "my-document-frame",
            frame: %{
              file_name: "template.tex",
              updated_at: "2024-11-29T12:56:47"
            },
            inserted_at: "2024-01-15T10:30:00Z",
            updated_at: "2024-01-15T10:30:00Z"
          },
          engine: %{
            id: "1232148nb3478",
            name: "Pandoc",
            api_route: "",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          },
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        creator: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule LayoutIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Layout Index",
      description: "List of layouts",
      type: :object,
      properties: %{
        layouts: LayoutsAndEngines,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        layouts: [
          %{
            id: "1232148nb3478",
            name: "Official Letter",
            description: "An official letter",
            width: 40.0,
            height: 20.0,
            unit: "cm",
            slug: "Pandoc",
            frame: %{
              id: "123e4567-e89b-12d3-a456-426614174000",
              name: "my-document-frame",
              frame: %{
                file_name: "template.tex",
                updated_at: "2024-11-29T12:56:47"
              },
              inserted_at: "2024-01-15T10:30:00Z",
              updated_at: "2024-01-15T10:30:00Z"
            },
            screenshot: "/official_letter.jpg",
            engine: %{
              id: "1232148nb3478",
              name: "Pandoc",
              api_route: "",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end

  defmodule Margin do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Margin",
      description: "Margins for layout",
      type: :object,
      properties: %{
        top: %Schema{type: :number, format: :float, description: "Top margin"},
        right: %Schema{type: :number, format: :float, description: "Right margin"},
        bottom: %Schema{type: :number, format: :float, description: "Bottom margin"},
        left: %Schema{type: :number, format: :float, description: "Left margin"}
      },
      required: [:top, :right, :bottom, :left],
      example: %{
        top: 2.5,
        right: 2.5,
        bottom: 2.5,
        left: 2.5
      }
    })
  end

  defmodule LayoutCreate do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "LayoutCreate",
      description: "Payload for creating a layout",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Layout name"},
        description: %Schema{type: :string, description: "Description"},
        width: %Schema{type: :string, description: "Layout width"},
        height: %Schema{type: :string, description: "Layout height"},
        unit: %Schema{type: :string, description: "Dimension unit"},
        slug: %Schema{type: :string, description: "Slug for the layout"},
        frame_id: %Schema{type: :string, description: "ID of the frame"},
        screenshot: %Schema{type: :string, description: "Screenshot file name or URL"},
        assets: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of asset IDs"
        },
        engine_id: %Schema{type: :string, description: "Layout engine ID"},
        margin: Margin
      },
      required: [:name, :description, :width, :height, :unit, :engine_id],
      example: %{
        name: "Letter Layout",
        description: "Standard letter page",
        width: "216",
        height: "279",
        unit: "mm",
        slug: "letter-layout",
        frame_id: "uuid-frame",
        screenshot: "letter_preview.png",
        assets: ["asset-1", "asset-2"],
        engine_id: "uuid-engine",
        margin: %{
          top: 2.5,
          right: 2.5,
          bottom: 2.5,
          left: 2.5
        }
      }
    })
  end
end
