defmodule WraftDocWeb.Api.V1.FormMappingController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug(WraftDocWeb.Plug.AddActionLog)

  plug(WraftDocWeb.Plug.Authorized,
    create: "form_mapping:manage",
    show: "form_mapping:show",
    update: "form_mapping:manage"
  )

  action_fallback(WraftDocWeb.FallbackController)

  require Logger
  alias WraftDoc.Document
  alias WraftDoc.Document.Pipeline.Stage
  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormMapping

  def swagger_definitions do
    %{
      FormMappingResponse:
        swagger_schema do
          title("Wraft Form mapping response")
          description("Form mapping response body")

          properties do
            form_id(:string, "Form id")
            pipe_stage_id(:string, "Pipe stage id")
            mapping(Schema.ref(:Mapping))
          end

          example(%{
            form_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            pipe_stage_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            inserted_at: "2023-08-21T14:00:00Z",
            updated_at: "2023-08-21T14:00:00Z",
            mapping: [
              %{
                id: "e63d02aa-6ea6-4e10-87aa-61061e7557eb",
                destination: %{
                  name: "E_name",
                  id: "992c50b2-c586-449f-b298-78d59d8ab81c"
                },
                source: %{
                  id: "992c50b2-c586-449f-b298-78d59d8ab81c",
                  name: "Name"
                }
              }
            ]
          })
        end,
      Mapping:
        swagger_schema do
          title("Form mapping")
          description("Mapping body")

          properties do
            mapping(
              :array,
              "Mapping body Example:
              `mapping: [{form_field_id: \"992c50b2-c586-449f-b298-78d59d8ab81c\", content_type_field_id: \"992c50b2-c586-449f-b298-78d59d8ab81c\"}]`",
              required: true
            )
          end
        end,
      FormMapping:
        swagger_schema do
          title("Wraft Form mapping")
          description("Form mapping body to create")

          properties do
            form_id(:string, "Form id", required: true)
            pipe_stage_id(:string, "Pipe stage id", required: true)
            mapping(Schema.ref(:Mapping))
          end

          example(%{
            pipe_stage_id: "0043bde9-3903-4cb7-b898-cd4d7cbe99bb",
            mapping: [
              %{
                destination: %{
                  name: "E_name",
                  destination_id: "992c50b2-c586-449f-b298-78d59d8ab81c"
                },
                source: %{
                  id: "992c50b2-c586-449f-b298-78d59d8ab81c",
                  name: "Name"
                }
              }
            ]
          })
        end
    }
  end

  swagger_path :create do
    post("/forms/{form_id}/mapping")
    summary("Create wraft form mapping")
    description("Create wraft form mapping API")

    parameters do
      form_id(:path, :string, "Form id", required: true)
      form_mapping(:body, Schema.ref(:FormMapping), "Form mapping to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:FormMappingResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  # TODO write test cases
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"form_id" => form_id} = params) do
    current_user = conn.assigns.current_user

    with %Form{} = _form <- Forms.get_form(current_user, form_id),
         %Stage{} <- Document.get_pipe_stage(current_user, params["pipe_stage_id"]),
         {:ok, %FormMapping{} = form_mapping} <- Forms.create_form_mapping(params) do
      render(conn, "create.json", form_mapping: form_mapping)
    end
  end

  swagger_path :show do
    get("/forms/{form_id}/mapping/{mapping_id}")
    summary("Get a form_mapping")
    description("get form_mapping API")

    parameters do
      form_id(:path, :string, "Form id", required: true)
      mapping_id(:path, :string, "form_mapping id", required: true)
    end

    response(200, "Ok", Schema.ref(:FormMappingResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  # TODO write test cases
  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, params) do
    current_user = conn.assigns.current_user

    with %FormMapping{} = form_mapping <- Forms.get_form_mapping(current_user, params) do
      render(conn, "show.json", form_mapping: form_mapping)
    end
  end

  swagger_path :update do
    put("/forms/{form_id}/mapping/{mapping_id}")
    summary("Update a form_mapping")
    description("Update form_mapping API")

    parameters do
      form_id(:path, :string, "Form id", required: true)
      mapping_id(:path, :string, "form_mapping id", required: true)

      form_mapping(
        :body,
        Schema.ref(:FormMapping),
        "FormMapping to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:FormMappingResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  # TODO write test cases
  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, params) do
    current_user = conn.assigns.current_user

    with %FormMapping{} = form_mapping <- Forms.get_form_mapping(current_user, params),
         {:ok, %FormMapping{} = form_mapping} <- Forms.update_form_mapping(form_mapping, params) do
      render(conn, "show.json", form_mapping: form_mapping)
    end
  end
end
