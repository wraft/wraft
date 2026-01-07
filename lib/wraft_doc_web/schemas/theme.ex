defmodule WraftDocWeb.Schemas.Theme do
  @moduledoc """
  Schema for Theme request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Theme do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Theme",
      description: "A Theme",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the theme"},
        name: %Schema{type: :string, description: "Theme's name"},
        font: %Schema{type: :string, description: "Font name"},
        typescale: %Schema{type: :object, description: "Typescale of the theme"},
        file: %Schema{type: :string, description: "Theme file attachment"},
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
      required: [:id, :name, :font, :typescale],
      example: %{
        id: "1232148nb3478",
        name: "Official Letter Theme",
        font: "Malery",
        typescale: %{h1: "10", p: "6", h2: "8"},
        file: "/malory.css",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z",
        assets: [
          "89face43-c408-4002-af3a-e8b2946f800a",
          "c70c6c80-d3ba-468c-9546-a338b0cf8d1c"
        ]
      }
    })
  end

  defmodule UpdateTheme do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Theme",
      description: "A Theme",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the theme"},
        name: %Schema{type: :string, description: "Theme's name"},
        font: %Schema{type: :string, description: "Font name"},
        typescale: %Schema{type: :object, description: "Typescale of the theme"},
        file: %Schema{type: :string, description: "Theme file attachment"},
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
      required: [:id, :name, :font, :typescale],
      example: %{
        id: "1232148nb3478",
        name: "Official Letter Theme",
        font: "Malery",
        typescale: %{h1: "10", p: "6", h2: "8"},
        file: "/malory.css",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule Themes do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All themes and its details",
      description:
        "All themes that have been created under current user's organisation and their details",
      type: :array,
      items: UpdateTheme
    })
  end

  defmodule ShowTheme do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show Theme",
      description: "Show details of a theme",
      type: :object,
      properties: %{
        theme: Theme,
        creator: WraftDocWeb.Schemas.User.User
      },
      example: %{
        theme: %{
          id: "1232148nb3478",
          name: "Official Letter Theme",
          font: "Malery",
          typescale: %{h1: "10", p: "6", h2: "8"},
          file: "/malory.css",
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

  defmodule ThemeIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Theme Index",
      description: "List of themes",
      type: :object,
      properties: %{
        themes: Themes,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        themes: [
          %{
            id: "1232148nb3478",
            name: "Official Letter Theme",
            font: "Malery",
            typescale: %{h1: "10", p: "6", h2: "8"},
            file: "/malory.css",
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
end
