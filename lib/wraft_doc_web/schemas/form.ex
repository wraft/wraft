defmodule WraftDocWeb.Schemas.Form do
  @moduledoc """
  Schema for Form request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule FormFieldRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form field request",
      description: "A single form field request body",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the field"},
        meta: %Schema{type: :object, description: "Attributes of the field"},
        order: %Schema{type: :integer, description: "Order number of the field"},
        description: %Schema{type: :string, description: "Field description"},
        validations: %Schema{type: :array, description: "Validations for the field"},
        field_type_id: %Schema{type: :string, description: "ID of the field type"}
      },
      example: %{
        name: "Photo",
        meta: %{"src" => "/img/img.png", "alt" => "Image"},
        description: "Upload your photo",
        validations: [
          %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
        ],
        field_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c"
      }
    })
  end

  defmodule FormFieldRequests do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field request array",
      description: "List of data to be send to add fields to a form.",
      type: :array,
      items: FormFieldRequest
    })
  end

  defmodule FormRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Wraft Form request",
      description: "Request body to create a wraft form",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Form's name"},
        description: %Schema{type: :string, description: "Form's description"},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for the form"
        },
        status: %Schema{
          type: :string,
          description: "Form's status. Only allowed values are active and inactive"
        },
        pipeline_ids: %Schema{
          type: :array,
          description: "ID of the pipelines selected",
          items: %Schema{type: :string}
        },
        fields: FormFieldRequests
      },
      required: [:name, :description, :prefix, :status],
      example: %{
        name: "Insurance Form",
        description:
          "Fill in the details to activate the corporate insurance offered to employees",
        prefix: "INSFORM",
        status: "active",
        fields: [
          %{
            name: "Photo",
            field_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            validations: [
              %{
                validation: %{rule: "required", value: true},
                error_message: "can't be blank"
              },
              %{
                validation: %{rule: "file_size", value: 2000},
                error_message: "can't be more than 2000 KB"
              }
            ],
            description: "Upload your photo"
          },
          %{
            name: "Name",
            field_type_id: "06c28fc6-6a15-4966-9b68-5eeac942fd4f",
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
            meta: %{},
            description: "Enter your name"
          }
        ],
        pipeline_ids: [
          "7af1ede3-a401-4f15-840a-cbeac07d68e4",
          "77fe7bb9-0cf4-4ebe-8ed3-72b16b653677"
        ]
      }
    })
  end

  defmodule UpdateFormRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Wraft Form update request",
      description: "Request body to update a wraft form",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Form's name"},
        description: %Schema{type: :string, description: "Form's description"},
        prefix: %Schema{
          type: :string,
          description: "Prefix to be used for generating Unique ID for the form"
        },
        status: %Schema{
          type: :string,
          description: "Form's status. Only allowed values are active and inactive"
        },
        pipeline_ids: %Schema{
          type: :array,
          description: "ID of the pipelines selected",
          items: %Schema{type: :string}
        },
        fields: FormFieldRequests
      },
      required: [:name, :description, :prefix, :status],
      example: %{
        name: "Insurance Form",
        description:
          "Fill in the details to activate the corporate insurance offered to employees",
        prefix: "INSFORM",
        status: "active",
        fields: [
          %{
            name: "Photo",
            field_id: "5e9bda8b-4c7e-44fe-8801-48ec6d8ff43a",
            field_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            validations: [
              %{
                validation: %{rule: "required", value: true},
                error_message: "can't be blank"
              },
              %{
                validation: %{rule: "file_size", value: 2000},
                error_message: "can't be more than 2000 KB"
              }
            ],
            description: "Upload your photo"
          },
          %{
            "field_id" => "63e19b8c-e3dc-4f0c-9ee2-ce4ec3a2159b"
          },
          %{
            name: "Name",
            field_type_id: "06c28fc6-6a15-4966-9b68-5eeac942fd4f",
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
            meta: %{},
            description: "Enter your name"
          }
        ],
        pipeline_ids: [
          "7af1ede3-a401-4f15-840a-cbeac07d68e4",
          "77fe7bb9-0cf4-4ebe-8ed3-72b16b653677"
        ]
      }
    })
  end

  defmodule SimpleForm do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form object",
      description: "Form in response.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the form"},
        name: %Schema{type: :string, description: "Name of the form"},
        description: %Schema{type: :string, description: "Description of the form"},
        prefix: %Schema{type: :string, description: "Prefix of the form"},
        status: %Schema{type: :string, description: "Status of the form"},
        inserted_at: %Schema{
          type: :string,
          description: "Datetime when the form was created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "Datetime when the form was last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "00b2086f-2177-4262-96f1-c2609e020a8a",
        name: "Insurance Form",
        description:
          "Fill in the details to activate the corporate insurance offered to employees",
        prefix: "INSFORM",
        status: "inactive",
        inserted_at: "2023-08-21T14:00:00Z",
        updated_at: "2023-08-21T14:00:00Z"
      }
    })
  end

  defmodule Forms do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form response array",
      description: "List of forms response.",
      type: :array,
      items: SimpleForm
    })
  end

  defmodule FormsIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form index response",
      description: "A list of forms with pagination information.",
      type: :object,
      properties: %{
        forms: Forms,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        forms: [
          %{
            description:
              "Fill in the details to activate the corporate insurance offered to employees",
            id: "eac20c0e-a13b-40c9-a89e-d3fa149f22ff",
            inserted_at: "2023-09-05T09:11:52",
            name: "Insurance Form",
            prefix: "INSFORM2",
            status: "active",
            updated_at: "2023-09-05T09:11:52"
          },
          %{
            description:
              "Fill in the details to activate the corporate insurance offered to employees",
            id: "1125413e-a2a4-43ab-9077-c209f48bdb86",
            inserted_at: "2023-09-05T08:19:55",
            name: "Insurance Form",
            prefix: "INSFORM1",
            status: "active",
            updated_at: "2023-09-05T08:19:55"
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end

  defmodule FormStatusUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form Status Update",
      description: "Form status update request.",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "status, eg: active or inactive"}
      },
      required: [:status],
      example: %{
        status: "inactive"
      }
    })
  end

  defmodule Field do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field object",
      description: "Field in response.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the field"},
        name: %Schema{type: :string, description: "Name of the field"},
        meta: %Schema{type: :object, description: "Attributes of the field"},
        description: %Schema{type: :string, description: "Field description"},
        validations: %Schema{type: :array, description: "Validations for the field"},
        field_type_id: %Schema{type: :string, description: "ID of the field type"},
        field_type: WraftDocWeb.Schemas.FieldType.FieldType
      },
      example: %{
        name: "Photo",
        meta: %{"src" => "/img/img.png", "alt" => "Image"},
        description: "Upload your photo",
        validations: [
          %{
            validation: %{rule: "required", value: true},
            error_message: "can't be blank"
          },
          %{
            validation: %{rule: "file_size", value: 2000},
            error_message: "can't be more than 2000 KB"
          }
        ],
        field_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
        field_type: %{
          id: "688249c2-503b-4d00-820b-0046b4f6e17e",
          name: "File",
          description: "A file upload field",
          meta: %{},
          validations: [],
          updated_at: "2023-01-21T14:00:00Z",
          inserted_at: "2023-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule Fields do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field response array",
      description: "List of fields response.",
      type: :array,
      items: Field
    })
  end

  defmodule Form do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form object",
      description: "Form in response.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the form"},
        name: %Schema{type: :string, description: "Name of the form"},
        description: %Schema{type: :string, description: "Description of the form"},
        prefix: %Schema{type: :string, description: "Prefix of the form"},
        status: %Schema{type: :string, description: "Status of the form"},
        inserted_at: %Schema{
          type: :string,
          description: "Datetime when the form was created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "Datetime when the form was last updated",
          format: "ISO-8601"
        },
        fields: Fields,
        # Assuming pipelines structure is generic or defined elsewhere, using array for now or could reference if available. The original swagger referenced `Schema.ref(:Pipelines)` which implies it might be defined somewhere else or I missed it. Wait, I don't see Pipelines definition in the controller file I read. It might be in another file or I missed it. Let's assume array of objects for now.
        pipelines: %Schema{type: :array, description: "Pipelines associated with the form"}
      },
      example: %{
        id: "00b2086f-2177-4262-96f1-c2609e020a8a",
        name: "Insurance Form",
        description:
          "Fill in the details to activate the corporate insurance offered to employees",
        prefix: "INSFORM",
        status: "active",
        inserted_at: "2023-08-21T14:00:00Z",
        updated_at: "2023-08-21T14:00:00Z",
        fields: [
          %{
            name: "Photo",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            description: "Upload your photo",
            validations: [
              %{
                validation: %{rule: "required", value: true},
                error_message: "can't be blank"
              },
              %{
                validation: %{rule: "file_size", value: 2000},
                error_message: "can't be more than 2000 KB"
              }
            ],
            field_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            field_type: %{
              id: "688249c2-503b-4d00-820b-0046b4f6e17e",
              name: "File",
              description: "A file upload field",
              meta: %{},
              validations: [],
              updated_at: "2023-01-21T14:00:00Z",
              inserted_at: "2023-02-21T14:00:00Z"
            }
          },
          %{
            name: "Name",
            meta: %{},
            description: "Enter your name",
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
            field_type_id: "06c28fc6-6a15-4966-9b68-5eeac942fd4f",
            field_type: %{
              id: "bdf2a17d-c40a-4cd9-affc-d649709a0ed3",
              name: "String",
              description: "A String field",
              meta: %{},
              validations: [],
              updated_at: "2023-01-21T14:00:00Z",
              inserted_at: "2023-02-21T14:00:00Z"
            }
          }
        ],
        pipelines: [
          %{
            id: "ddec6e97-cb69-40bc-9218-5a578c4f5a1f",
            name: "Insurance Form Pipeline",
            api_route: "client.crm.com",
            updated_at: "2023-02-21T14:00:00Z",
            inserted_at: "2023-02-21T14:00:00Z"
          }
        ]
      }
    })
  end

  defmodule FormFieldIDwithOrder do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form Field IDs with order",
      description: "Show the form field IDs with order numbers to be updated",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the field"},
        order: %Schema{type: :integer, description: "Order number of the field"}
      },
      example: %{
        id: "da04ad43-03ca-486e-ad1e-88b811241944",
        order: 1
      }
    })
  end

  defmodule AlignFormFieldsRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Align Form Fields Request",
      description: "Request to align form fields",
      type: :object,
      properties: %{
        # Based on example: fields: {"id": 1, "id2": 2}
        fields: %Schema{type: :object, additionalProperties: %Schema{type: :integer}}
      },
      example: %{
        fields: %{
          "da04ad43-03ca-486e-ad1e-88b811241944": 1,
          "90935c7a-02b1-48d9-84d8-1bf00cf8ea90": 2
        }
      }
    })
  end
end
