defmodule WraftDocWeb.Api.V1.FormController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug(WraftDocWeb.Plug.AddActionLog)

  plug(WraftDocWeb.Plug.Authorized,
    create: "form:manage",
    index: "form:show",
    show: "form:show",
    update: "form:manage",
    delete: "form:delete"
  )

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form

  def swagger_definitions do
    %{
      FormRequest:
        swagger_schema do
          title("Wraft Form request")
          description("Request body to cerate a wraft form")

          properties do
            name(:string, "Form's name", required: true)
            description(:string, "Form's description", required: true)

            prefix(:string, "Prefix to be used for generating Unique ID for the form",
              required: true
            )

            status(:string, "Form's status. Only allowed values are active and inactive",
              required: true
            )

            pipeline_ids(:array, "ID of the pipelines selected", required: false)

            fields(Schema.ref(:FormFieldRequests))
          end

          example(%{
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
          })
        end,
      FormFieldRequests:
        swagger_schema do
          title("Field request array")
          description("List of data to be send to add fields to a form.")
          type(:array)
          items(Schema.ref(:FormFieldRequest))
        end,
      FormFieldRequest:
        swagger_schema do
          title("Form field request")
          description("A single form field request body")

          properties do
            name(:string, "Name of the field")
            meta(:map, "Attributes of the field")
            description(:string, "Field description")
            validations(Schema.ref(:Validations))
            field_type_id(:string, "ID of the field type")
          end

          example(%{
            name: "Photo",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            description: "Upload your photo",
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
            field_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c"
          })
        end,
      FormsIndex:
        swagger_schema do
          title("Form index response")
          description("A list of forms with pagination information.")

          properties do
            forms(Schema.ref(:Forms))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            forms: [
              %{
                id: "5a324612-0f90-4649-951c-1f67d8882c75",
                name: "Insurance Form",
                description:
                  "Fill in the details to activate the corporate insurance offered to employees",
                fields: [
                  %{key: "position", field_type_id: "kjb14713132lkdac"},
                  %{key: "name", field_type_id: "kjb2347mnsad"}
                ],
                prefix: "INSFORM",
                status: "active",
                updated_at: "2023-08-21T14:00:00Z",
                inserted_at: "2023-08-21T14:00:00Z",
                creator: %{
                  id: "2b1521db-9882-4db0-b525-ecddc7bacccd",
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
          })
        end,
      Forms:
        swagger_schema do
          title("Form response array")
          description("List of forms response.")
          type(:array)
          items(Schema.ref(:Form))
        end,
      Form:
        swagger_schema do
          title("Form object")
          description("Form in response.")

          properties do
            id(:string, "ID of the form")
            name(:string, "Name of the form")
            description(:string, "Description of the form")
            prefix(:string, "Prefix of the form")
            status(:string, "Status of the form")
            inserted_at(:string, "Datetime when the form was created", format: "ISO-8601")
            updated_at(:string, "Datetime when the form was last updated", format: "ISO-8601")

            fields(Schema.ref(:Fields))
            pipelines(Schema.ref(:Pipelines))
          end

          example(%{
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
          })
        end,
      Fields:
        swagger_schema do
          title("Field response array")
          description("List of fields response.")
          type(:array)
          items(Schema.ref(:Field))
        end,
      Field:
        swagger_schema do
          title("Field object")
          description("Field in response.")

          properties do
            id(:string, "ID of the field")
            name(:string, "Name of the field")
            meta(:map, "Attributes of the field")
            description(:string, "Field description")
            validations(Schema.ref(:Validations))
            field_type_id(:string, "ID of the field type")
            field_type(Schema.ref(:FieldType))
          end

          example(%{
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
          })
        end
    }
  end

  swagger_path :create do
    post("/forms")
    summary("Create wraft form")
    description("Create wraft form API")

    parameters do
      form(:body, Schema.ref(:FormRequest), "Form Type to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Form))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.create(current_user, params) do
      render(conn, "form.json", form: form)
    end
  end
end
