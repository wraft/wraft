defmodule WraftDocWeb.Schemas.DataTemplate do
  @moduledoc """
  Schema for DataTemplate request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule DataTemplateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data template Request",
      description: "Create data template request.",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Data template's title"},
        title_template: %Schema{type: :string, description: "Title template"},
        data: %Schema{type: :string, description: "Data template's contents"},
        serialized: %Schema{type: :object, description: "Serialized data"}
      },
      required: [:title, :title_template, :data, :serialized],
      example: %{
        title: "Template 1",
        title_template: "Letter for [user]",
        data: "Hi [user]",
        serialized: %{title: "Offer letter of [client]", data: "Hi [user]"}
      }
    })
  end

  defmodule DataTemplate do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data Template",
      description: "A Data Template",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the data template"},
        title: %Schema{type: :string, description: "Title of the data template"},
        title_template: %Schema{type: :string, description: "Title content of the data template"},
        data: %Schema{type: :string, description: "Data template's contents"},
        serialized: %Schema{type: :object, description: "Serialized data"},
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
      required: [:id, :title, :title_template],
      example: %{
        id: "1232148nb3478",
        title: "Template 1",
        title_template: "Letter for [user]",
        data: "Hi [user]",
        serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule DataTemplateAndContentType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data Template and its content type",
      description: "A Data Template and its content type",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the data template"},
        title: %Schema{type: :string, description: "Title of the data template"},
        title_template: %Schema{type: :string, description: "Title content of the data template"},
        data: %Schema{type: :string, description: "Data template's contents"},
        serialized: %Schema{type: :object, description: "Serialized data"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the layout created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the layout last updated",
          format: "ISO-8601"
        },
        content_type: %Schema{anyOf: [WraftDocWeb.Schemas.ContentType.ContentTypeWithoutFields]}
      },
      required: [:id, :title, :title_template],
      example: %{
        id: "1232148nb3478",
        title: "Template 1",
        title_template: "Letter for [user]",
        data: "Hi [user]",
        serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z",
        content_type: %{
          id: "1232148nb3478",
          name: "Offer letter",
          description: "An offer letter",
          prefix: "OFFLET",
          color: "#fffff",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule ShowDataTemplate do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data template and all its details",
      description: "API to show a data template and all its details",
      type: :object,
      properties: %{
        data_template: %Schema{anyOf: [DataTemplate]},
        creator: %Schema{anyOf: [WraftDocWeb.Schemas.User.User]},
        content_type: %Schema{anyOf: [WraftDocWeb.Schemas.ContentType.ContentTypeWithoutFields]}
      },
      example: %{
        data_template: %{
          id: "1232148nb3478",
          title: "Main Template",
          title_template: "Letter for [user]",
          data: "Hi [user]",
          serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
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
        },
        content_type: %{
          id: "1232148nb3478",
          name: "Offer letter",
          description: "An offer letter",
          prefix: "OFFLET",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule DataTemplates do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data templates under a content type",
      description: "All data template that have been created under a content type",
      type: :array,
      items: DataTemplate
    })
  end

  defmodule DataTemplatesIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data Templates Index",
      type: :object,
      properties: %{
        data_templates: %Schema{type: :array, items: DataTemplateAndContentType},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        data_templates: [
          %{
            id: "1232148nb3478",
            title: "Main template",
            title_template: "Letter for [user]",
            data: "Hi [user]",
            serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              prefix: "OFFLET",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
