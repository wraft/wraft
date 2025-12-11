defmodule WraftDocWeb.Schemas.ContentType do
  @moduledoc """
  Schema for ContentType request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

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
        fields: %Schema{anyOf: [WraftDocWeb.Schemas.ContentType.ContentTypeFieldRequests]},
        layout_id: %Schema{type: :string, description: "ID of the layout selected"},
        flow_id: %Schema{type: :string, description: "ID of the flow selected"},
        theme_id: %Schema{type: :string, description: "ID of the flow selected"},
        color: %Schema{type: :string, description: "Hex code of color"},
        frame_mapping: %Schema{anyOf: [WraftDocWeb.Schemas.ContentType.ContentTypeFrameMapping]},
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
            field_type_id: "kjb14713132lkdac",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            description: "a text input"
          },
          %{name: "name", field_type_id: "kjb2347mnsad"}
        ],
        layout_id: "1232148nb3478",
        flow_id: "234okjnskjb8234",
        theme_id: "123ki3491n49",
        prefix: "OFFLET",
        color: "#fff",
        frame_mapping: [
          %{"source" => "Proposal_type", "destination" => "Title"},
          %{"source" => "Project_name", "destination" => "Project"},
          %{"source" => "Ref_no", "destination" => "Quotation Ref No"},
          %{"source" => "Client_name", "destination" => "Proposed to"}
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
        field_type_id: "asdlkne4781234123clk",
        meta: %{"src" => "/img/img.png", "alt" => "Image"},
        description: "text input"
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
        field_type: %Schema{anyOf: [WraftDocWeb.Schemas.FieldType.FieldType]}
      },
      example: %{
        name: "position",
        field_type_id: "asdlkne4781234123clk",
        meta: %{"src" => "/img/img.png", "alt" => "Image"}
      }
    })
  end

  defmodule ContentTypeFields do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field response array",
      description: "List of field type in response.",
      type: :array,
      items: ContentTypeField
    })
  end

  defmodule ContentTypeFieldRequests do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field request array",
      description: "List of data to be send to add fields to content type.",
      type: :array,
      items: ContentTypeFieldRequest
    })
  end

  defmodule ContentTypeFrameMapping do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Frame Mapping",
      description: "Mapping of fields between source and destination",
      type: :object,
      properties: %{
        mapping: %Schema{type: :array, description: "List of frame field mappings"}
      },
      required: [:mapping],
      example: %{
        mapping: [
          %{"source" => "Proposal_type", "destination" => "Title"},
          %{"source" => "Sub Title", "destination" => "Sub title"},
          %{"source" => "Project_name", "destination" => "Project"},
          %{"source" => "Ref_no", "destination" => "Quotation Ref No"},
          %{"source" => "Client_name", "destination" => "Proposed to"},
          %{"source" => "Date", "destination" => "Date"}
        ]
      }
    })
  end

  defmodule ContentTypeWithFields do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type",
      description: "A Content Type.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        color: %Schema{type: :string, description: "Hex code of color"},
        fields: %Schema{anyOf: [ContentTypeFields]},
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
        id: "1232148nb3478",
        name: "Offer letter",
        description: "An offer letter",
        fields: [
          %{
            name: "position",
            field_type_id: "kjb14713132lkdac",
            meta: %{"src" => "/img/img.png", "alt" => "Image"}
          },
          %{
            name: "name",
            field_type_id: "kjb2347mnsad",
            meta: %{"src" => "/img/img.png", "alt" => "Image"}
          }
        ],
        prefix: "OFFLET",
        color: "#fffff",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
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
        id: "1232148nb3478",
        name: "Offer letter",
        description: "An offer letter",
        prefix: "OFFLET",
        color: "#fffff",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ContentTypeAndLayout do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type and Layout",
      description: "Content Type to be used for the generation of a document and its layout.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        fields: %Schema{anyOf: [ContentTypeFields]},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        },
        color: %Schema{type: :string, description: "Hex code of color"},
        layout: %Schema{anyOf: [WraftDocWeb.Schemas.Layout.Layout]},
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
        id: "1232148nb3478",
        name: "Offer letter",
        description: "An offer letter",
        fields: [
          %{name: "position", field_type_id: "kjb14713132lkdac"},
          %{name: "name", field_type_id: "kjb2347mnsad"}
        ],
        prefix: "OFFLET",
        color: "#fffff",
        layout: %{
          id: "1232148nb3478",
          name: "Official Letter",
          description: "An official letter",
          width: 40.0,
          height: 20.0,
          unit: "cm",
          slug: "Pandoc",
          slug_file: "/letter.zip",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ContentTypeAndLayoutAndFlowAndTheme do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type, Layout and its flow",
      description:
        "Content Type to be used for the generation of a document, its layout and flow.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        type: %Schema{type: :string, description: "Content Type's type eg: contract"},
        fields: %Schema{anyOf: [ContentTypeFields]},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        },
        color: %Schema{type: :string, description: "Hex code of color"},
        layout: %Schema{anyOf: [WraftDocWeb.Schemas.Layout.Layout]},
        flow: %Schema{anyOf: [WraftDocWeb.Schemas.Flow.Flow]},
        field_type: %Schema{anyOf: [WraftDocWeb.Schemas.FieldType.FieldType]},
        theme: %Schema{anyOf: [WraftDocWeb.Schemas.Theme.Theme]},
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
        id: "1232148nb3478",
        name: "Offer letter",
        description: "An offer letter",
        fields: [
          %{name: "position", field_type_id: "kjb14713132lkdac"},
          %{name: "name", field_type_id: "kjb2347mnsad"}
        ],
        prefix: "OFFLET",
        color: "#fffff",
        theme: %{
          id: "1232148nb3478",
          name: "Official Letter Theme",
          font: "Malery",
          typescale: %{h1: "10", p: "6", h2: "8"},
          file: "/malory.css",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z",
          assets: [
            %{
              id: "c70c6c80-d3ba-468c-9546-a338b0cf8d1c",
              name: "Asset",
              type: "theme",
              file: "Roboto-Bold.ttf",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            %{
              id: "89face43-c408-4002-af3a-e8b2946f800a",
              name: "Asset",
              type: "theme",
              file: "Roboto-Regular.ttf",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          ]
        },
        layout: %{
          id: "1232148nb3478",
          name: "Official Letter",
          description: "An official letter",
          width: 40.0,
          height: 20.0,
          unit: "cm",
          slug: "Pandoc",
          slug_file: "/letter.zip",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        flow: %{
          id: "1232148nb3478",
          name: "Flow 1",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ContentTypesAndLayoutsAndFlows do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Types and their Layouts and flow",
      description: "All content types that have been created and their layouts and flow",
      type: :array,
      items: ContentTypeAndLayoutAndFlowAndTheme
    })
  end

  defmodule ContentTypeAndLayoutAndFlowAndStates do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type, Layout, Flow and states",
      description:
        "Content Type to be used for the generation of a document, its layout, flow and states.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content type"},
        name: %Schema{type: :string, description: "Content Type's name"},
        description: %Schema{type: :string, description: "Content Type's description"},
        type: %Schema{type: :string, description: "Type of content type, eg: contract"},
        fields: %Schema{anyOf: [ContentTypeFields]},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        },
        color: %Schema{type: :string, description: "Hex code of color"},
        layout: %Schema{anyOf: [WraftDocWeb.Schemas.Layout.Layout]},
        flow: %Schema{anyOf: [WraftDocWeb.Schemas.Flow.FlowAndStatesWithoutCreator]},
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
        id: "1232148nb3478",
        name: "Offer letter",
        description: "An offer letter",
        type: "contract",
        fields: [
          %{name: "position", field_type_id: "kjb14713132lkdac"},
          %{name: "name", field_type_id: "kjb2347mnsad"}
        ],
        prefix: "OFFLET",
        color: "#fffff",
        layout: %{
          id: "1232148nb3478",
          name: "Official Letter",
          description: "An official letter",
          width: 40.0,
          height: 20.0,
          unit: "cm",
          slug: "Pandoc",
          slug_file: "/letter.zip",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        flow: %{
          id: "1232148nb3478",
          name: "Flow 1",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z",
          states: [
            %{
              id: "1232148nb3478",
              state: "published",
              order: 1
            }
          ]
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ShowContentType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Type and all its details",
      description: "API to show a content type and all its details",
      type: :object,
      properties: %{
        content_type: %Schema{anyOf: [ContentTypeAndLayoutAndFlowAndTheme]},
        creator: %Schema{anyOf: [WraftDocWeb.Schemas.User.User]}
      },
      example: %{
        content_type: %{
          id: "1232148nb3478",
          name: "Offer letter",
          description: "An offer letter",
          type: "contract",
          fields: [
            %{name: "position", field_type_id: "kjb14713132lkdac"},
            %{name: "name", field_type_id: "kjb2347mnsad"}
          ],
          prefix: "OFFLET",
          color: "#fffff",
          flow: %{
            id: "1232148nb3478",
            name: "Flow 1",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            states: [
              %{
                id: "1232148nb3478",
                state: "published",
                order: 1
              }
            ]
          },
          theme: %{
            id: "1232148nb3478",
            name: "Official Letter Theme",
            font: "Malery",
            typescale: %{h1: "10", p: "6", h2: "8"},
            file: "/malory.css",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            assets: [
              %{
                id: "c70c6c80-d3ba-468c-9546-a338b0cf8d1c",
                name: "Asset",
                type: "theme",
                file: "Roboto-Bold.ttf",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              },
              %{
                id: "89face43-c408-4002-af3a-e8b2946f800a",
                name: "Asset",
                type: "theme",
                file: "Roboto-Regular.ttf",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ]
          },
          layout: %{
            id: "1232148nb3478",
            name: "Official Letter",
            description: "An official letter",
            width: 40.0,
            height: 20.0,
            unit: "cm",
            slug: "Pandoc",
            slug_file: "/letter.zip",
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

  defmodule ContentTypesIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Types Index",
      description: "List of content types",
      type: :object,
      properties: %{
        content_types: ContentTypesAndLayoutsAndFlows,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        content_types: [
          %{
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              fields: [
                %{name: "position", field_type_id: "kjb14713132lkdac"},
                %{name: "name", field_type_id: "kjb2347mnsad"}
              ],
              prefix: "OFFLET",
              color: "#fffff",
              flow: %{
                id: "1232148nb3478",
                name: "Flow 1",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              },
              layout: %{
                id: "1232148nb3478",
                name: "Official Letter",
                description: "An official letter",
                width: 40.0,
                height: 20.0,
                unit: "cm",
                slug: "Pandoc",
                slug_file: "/letter.zip",
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
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end

  defmodule ContentTypeRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type role",
      description: "List of roles under content type",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the content_type"},
        description: %Schema{type: :string, description: "Content Type's description"},
        layout_id: %Schema{type: :string, description: "ID of the layout selected"},
        flow_id: %Schema{type: :string, description: "ID of the flow selected"},
        color: %Schema{type: :string, description: "Hex code of color"},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        }
      },
      required: [:description, :layout_id, :flow_id, :prefix]
    })
  end

  defmodule ContentTypeSearch do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type search",
      description: "Search the content search",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the content_type"},
        description: %Schema{type: :string, description: "Content Type's description"},
        color: %Schema{type: :string, description: "Hex code of color"},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for contents"
        }
      },
      required: [:description, :prefix],
      example: %{
        page_number: 1,
        total_entries: 2,
        total_pages: 1,
        content_types: [
          %{
            description: "content type",
            id: "466f1fa1-9657-4166-b372-21e8135aeaf1",
            color: "red",
            prefix: "ex"
          }
        ]
      }
    })
  end
end
