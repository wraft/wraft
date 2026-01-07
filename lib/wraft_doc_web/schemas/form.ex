defmodule WraftDocWeb.Schemas.Form do
  @moduledoc """
  Schema for Form request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.FieldType

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
        field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
      }
    })
  end

  defmodule FormFieldRequests do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field request array",
      description: "List of data to be send to add fields to a form.",
      type: :array,
      items: FormFieldRequest,
      example: [
        %{
          name: "Photo",
          meta: %{"src" => "/img/img.png", "alt" => "Image"},
          description: "Upload your photo",
          validations: [
            %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
          ],
          field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
        }
      ]
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
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
            meta: %{},
            description: "Enter your name"
          }
        ],
        pipeline_ids: [
          "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          "3fa85f64-5717-4562-b3fc-2c963f66afa6"
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
            field_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
            "field_id" => "3fa85f64-5717-4562-b3fc-2c963f66afa6"
          },
          %{
            name: "Name",
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
            meta: %{},
            description: "Enter your name"
          }
        ],
        pipeline_ids: [
          "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          "3fa85f64-5717-4562-b3fc-2c963f66afa6"
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
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
      items: SimpleForm,
      example: [
        %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "Insurance Form",
          description: "Fill in the details",
          prefix: "INSFORM",
          status: "inactive",
          inserted_at: "2023-08-21T14:00:00Z",
          updated_at: "2023-08-21T14:00:00Z"
        }
      ]
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
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            inserted_at: "2023-09-05T09:11:52",
            name: "Insurance Form",
            prefix: "INSFORM2",
            status: "active",
            updated_at: "2023-09-05T09:11:52"
          },
          %{
            description:
              "Fill in the details to activate the corporate insurance offered to employees",
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
        field_type: FieldType.FieldType
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
        field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        field_type: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
      items: Field,
      example: [
        %{
          name: "Photo",
          meta: %{"src" => "/img/img.png", "alt" => "Image"},
          description: "Upload your photo",
          validations: [],
          field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          field_type: %{
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            name: "File",
            description: "A file upload field",
            meta: %{},
            validations: [],
            updated_at: "2023-01-21T14:00:00Z",
            inserted_at: "2023-02-21T14:00:00Z"
          }
        }
      ]
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
        pipelines: %Schema{type: :array, description: "Pipelines associated with the form"}
      },
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            field_type: %{
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
            field_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            field_type: %{
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
          "3fa85f64-5717-4562-b3fc-2c963f66afa6": 1,
          "3fa85f64-5717-4562-b3fc-2c963f66afa7": 2
        }
      }
    })
  end
end
