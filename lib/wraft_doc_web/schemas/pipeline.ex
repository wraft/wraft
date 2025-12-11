defmodule WraftDocWeb.Schemas.Pipeline do
  @moduledoc """
  Schema for Pipeline request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule PipeStageRequestItem do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipe Stage Request Item",
      description: "Map with content type and data template UUIDs",
      type: :object,
      properties: %{
        content_type_id: %Schema{type: :string, description: "Content Type ID"},
        data_template_id: %Schema{type: :string, description: "Data Template ID"}
      },
      example: %{
        content_type_id: "12lkjn3490u12",
        data_template_id: "23e40p9lknsd478"
      }
    })
  end

  defmodule PipeStageRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipe stage request list",
      description: "List of maps with content type, data template and state UUIDs",
      type: :array,
      items: PipeStageRequestItem,
      example: [
        %{
          content_type_id: "12lkjn3490u12",
          data_template_id: "23e40p9lknsd478"
        },
        %{
          content_type_id: "1232148nb3478",
          data_template_id: "1232148nb3478"
        }
      ]
    })
  end

  defmodule PipelineRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipeline Request",
      description: "Create pipeline request.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Pipeline's name"},
        source: %Schema{type: :string, description: "Source, eg: WraftForms"},
        source_id: %Schema{type: :string, description: "Source ID, eg: Form ID"},
        api_route: %Schema{type: :string, description: "Pipeline's API route"},
        stages: PipeStageRequest
      },
      required: [:name, :source, :source_id, :api_route],
      example: %{
        name: "Pipeline 1",
        api_route: "client.crm.com",
        source: "WraftForms",
        source_id: "1232148nb3478",
        stages: [
          %{
            content_type_id: "12lkjn3490u12",
            data_template_id: "23e40p9lknsd478"
          },
          %{
            content_type_id: "1232148nb3478",
            data_template_id: "1232148nb3478"
          }
        ]
      }
    })
  end

  defmodule Pipeline do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipeline",
      description: "Pipeline to generate multiple docs.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the pipeline"},
        name: %Schema{type: :string, description: "Name of the pipeline"},
        source: %Schema{type: :string, description: "Source for the pipeline, eg: WraftForms"},
        source_id: %Schema{type: :string, description: "Source ID for the pipeline, eg: Form ID"},
        api_route: %Schema{type: :string, description: "API route of the CRM"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the flow inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the flow last updated"
        }
      },
      example: %{
        id: "1232148nb3478",
        name: "Pipeline 1",
        source: "WraftForms",
        source_id: "1232148nb3478",
        api_route: "client.crm.com",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule PipeStage do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipe Stage",
      type: :object,
      properties: %{
        content_type: %Schema{type: :object, description: "Content Type details"},
        data_template: %Schema{type: :object, description: "Data Template details"}
      }
    })
  end

  defmodule PipelineAndStages do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipeline and its stages",
      description: "Show a pipeline and its stages.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the pipeline"},
        name: %Schema{type: :string, description: "Name of the pipeline"},
        source: %Schema{type: :string, description: "Source for the pipeline, eg: WraftForms"},
        source_id: %Schema{type: :string, description: "Source ID for the pipeline, eg: Form ID"},
        api_route: %Schema{type: :string, description: "API route of the CRM"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the flow inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the flow last updated"
        },
        stages: %Schema{type: :array, items: PipeStage}
      },
      example: %{
        id: "1232148nb3478",
        name: "Pipeline 1",
        source: "WraftForms",
        source_id: "1232148nb3478",
        api_route: "client.crm.com",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z",
        stages: [
          %{
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              prefix: "OFFLET",
              color: "#fffff",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z",
              fields: [
                %{
                  key: "position",
                  field_type_id: "kjb14713132lkdac",
                  meta: %{"src" => "/img/img.png", "alt" => "Image"}
                },
                %{
                  key: "name",
                  field_type_id: "kjb2347mnsad",
                  meta: %{"src" => "/img/img.png", "alt" => "Image"}
                }
              ]
            },
            data_template: %{
              id: "1232148nb3478",
              title: "Template 1",
              title_template: "Letter for [user]",
              data: "Hi [user]",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          }
        ]
      }
    })
  end

  defmodule ShowPipeline do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show pipeline",
      description: "Show details of a pipeline",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the pipeline"},
        name: %Schema{type: :string, description: "Name of the pipeline"},
        source: %Schema{type: :string, description: "Source for the pipeline, eg: WraftForms"},
        source_id: %Schema{type: :string, description: "Source ID for the pipeline, eg: Form ID"},
        api_route: %Schema{type: :string, description: "API route of the CRM"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the flow inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the flow last updated"
        },
        stages: %Schema{type: :array, items: PipeStage},
        # Placeholder for User
        creator: %Schema{type: :object}
      }
    })
  end

  defmodule PipelineIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pipeline Index",
      type: :object,
      properties: %{
        pipelines: %Schema{type: :array, items: Pipeline},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        pipelines: [
          %{
            id: "1232148nb3478",
            name: "Pipeline 1",
            source: "WraftForms",
            source_id: "1232148nb3478",
            api_route: "client.crm.com",
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
