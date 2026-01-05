defmodule WraftDocWeb.Schemas.ContentType do
  @moduledoc """
  Schema for ContentType request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.{FieldType, Flow, Layout, Theme, User}

  defmodule ContentTypeFrameMapping do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Frame Mapping",
      description: "Mapping of fields between source and destination",
      type: :object,
      properties: %{
        mapping: %Schema{
          type: :array,
          description: "List of frame field mappings",
          items: %Schema{type: :object}
        }
      },
      example: %{
        mapping: [
          %{"source" => "Proposal_type", "destination" => "Title"},
          %{"source" => "Sub Title", "destination" => "Sub title"}
        ]
      }
    })
  end

  defmodule ContentTypeFieldRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type field request",
      description: "Data to be send to add fields to content type.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the field"},
        meta: %Schema{type: :object, description: "Attributes of the field"},
        description: %Schema{type: :string, description: "Field description"},
        field_type_id: %Schema{type: :string, description: "ID of the field type"}
      },
      example: %{
        name: "position",
        field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        meta: %{"src" => "/img/img.png", "alt" => "Image"},
        description: "text input"
      }
    })
  end

  defmodule ContentTypeRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type Request",
      description: "Create content type request.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        type: %Schema{type: :string, description: "Type of content type, eg: contract"},
        fields: %Schema{type: :array, items: ContentTypeFieldRequest},
        layout_id: %Schema{type: :string, description: "ID of the layout selected"},
        flow_id: %Schema{type: :string, description: "ID of the flow selected"},
        theme_id: %Schema{type: :string, description: "ID of the theme selected"},
        color: %Schema{type: :string, description: "Hex code of color"},
        frame_mapping: ContentTypeFrameMapping,
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        }
      },
      required: [:name, :description, :layout_id, :flow_id, :theme_id, :prefix],
      example: %{
        name: "Offer letter",
        description: "An offer letter",
        type: "contract",
        fields: [
          %{
            name: "position",
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            description: "a text input"
          }
        ],
        layout_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        flow_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        theme_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        prefix: "OFFLET",
        color: "#fff",
        frame_mapping: %{
          mapping: [
            %{"source" => "Proposal_type", "destination" => "Title"}
          ]
        }
      }
    })
  end

  defmodule ContentTypeField do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type field in response",
      description: "Content type field in respone.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of content type field"},
        name: %Schema{type: :string, description: "Name of content type field"},
        meta: %Schema{type: :object, description: "Attributes of the field"},
        description: %Schema{type: :string, description: "Field description"},
        order: %Schema{type: :integer, description: "Order of the field"},
        required: %Schema{type: :boolean, description: "Is field required"},
        machine_name: %Schema{type: :string, description: "Machine name of the field"},
        validations: %Schema{
          type: :array,
          items: %Schema{type: :object},
          description: "Validations"
        },
        field_type: FieldType.FieldType
      },
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "position",
        field_type: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "Text",
          type: "text",
          icon: "text_icon",
          inserted_at: "2020-01-21T14:00:00Z",
          updated_at: "2020-01-21T14:00:00Z"
        },
        meta: %{"src" => "/img/img.png", "alt" => "Image"},
        order: 1,
        required: true,
        machine_name: "position_field",
        validations: []
      }
    })
  end

  defmodule ContentTypeFull do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type Full Details",
      description: "Content Type with all details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        type: %Schema{type: :string, description: "Content Type's type"},
        fields: %Schema{type: :array, items: ContentTypeField},
        prefix: %Schema{type: :string, description: "Prefix"},
        color: %Schema{type: :string, description: "Hex code of color"},
        frame_mapping: ContentTypeFrameMapping,
        layout: Layout.Layout,
        flow: %Schema{anyOf: [Flow.FlowBase, Flow.FlowAndStatesWithoutCreator]},
        theme: Theme.Theme,
        inserted_at: %Schema{type: :string, format: "ISO-8601"},
        updated_at: %Schema{type: :string, format: "ISO-8601"}
      }
    })
  end

  defmodule ContentTypeResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type Response (Flat)",
      description: "Content Type response for create/index",
      allOf: [
        ContentTypeFull,
        %Schema{
          type: :object,
          properties: %{
            creator: User.User
          }
        }
      ]
    })
  end

  defmodule ShowContentType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show Content Type",
      description: "Response for show content type",
      type: :object,
      properties: %{
        content_type: ContentTypeFull,
        creator: User.User
      }
    })
  end

  defmodule ContentTypesIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Types Index",
      description: "List of content types",
      type: :object,
      properties: %{
        content_types: %Schema{type: :array, items: ContentTypeResponse},
        page_number: %Schema{type: :integer},
        total_pages: %Schema{type: :integer},
        total_entries: %Schema{type: :integer}
      }
    })
  end

  defmodule ContentTypeWithoutFields do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type without fields",
      description: "A Content Type without its fields.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        type: %Schema{type: :string, description: "Type of the content type eg: contract"},
        color: %Schema{type: :string, description: "Hex code of color"},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        },
        inserted_at: %Schema{
          type: :string,
          description: "When was the user inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the user last updated",
          format: "ISO-8601"
        }
      },
      required: [:id, :name],
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "Offer letter",
        description: "An offer letter",
        prefix: "OFFLET",
        color: "#fffff",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ContentTypeRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type role",
      description: "Content type role details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the content_type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        color: %Schema{type: :string, description: "Hex code of color"},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        },
        inserted_at: %Schema{type: :string, format: "ISO-8601"},
        updated_at: %Schema{type: :string, format: "ISO-8601"}
      },
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "Offer Letter",
        description: "An offer letter",
        color: "#fffff",
        prefix: "OFFLET",
        inserted_at: "2020-01-21T14:00:00Z",
        updated_at: "2020-01-21T14:00:00Z"
      }
    })
  end

  defmodule RoleContentType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Role Content Type",
      description: "Simplified content type for role associations",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        color: %Schema{type: :string, description: "Hex code of color"},
        prefix: %Schema{type: :string, description: "Prefix"},
        inserted_at: %Schema{type: :string, format: "ISO-8601"},
        updated_at: %Schema{type: :string, format: "ISO-8601"}
      },
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "Offer Letter",
        description: "An offer letter",
        color: "#fffff",
        prefix: "OFFLET",
        inserted_at: "2020-01-21T14:00:00Z",
        updated_at: "2020-01-21T14:00:00Z"
      }
    })
  end
end
