defmodule WraftDocWeb.Api.V1.FormMappingController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug(WraftDocWeb.Plug.AddActionLog)

  action_fallback(WraftDocWeb.FallbackController)

  require Logger
  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormMapping
  alias WraftDoc.Pipelines.Stages
  alias WraftDoc.Pipelines.Stages.Stage
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.FormMapping, as: FormMappingSchema

  tags(["Form Mappings"])

  operation(:create,
    summary: "Create wraft form mapping",
    description: "Create wraft form mapping API",
    parameters: [
      form_id: [in: :path, type: :string, description: "Form id", required: true]
    ],
    request_body:
      {"Form mapping to be created", "application/json", FormMappingSchema.FormMapping},
    responses: [
      ok: {"Ok", "application/json", FormMappingSchema.FormMappingResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  # TODO write test cases
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"form_id" => form_id} = params) do
    current_user = conn.assigns.current_user

    with %Form{} = _form <- Forms.get_form(current_user, form_id),
         %Stage{} <- Stages.get_pipe_stage(current_user, params["pipe_stage_id"]),
         {:ok, %FormMapping{} = form_mapping} <- Forms.create_form_mapping(params) do
      render(conn, "create.json", form_mapping: form_mapping)
    end
  end

  operation(:show,
    summary: "Get a form_mapping",
    description: "get form_mapping API",
    parameters: [
      form_id: [in: :path, type: :string, description: "Form id", required: true],
      mapping_id: [in: :path, type: :string, description: "form_mapping id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FormMappingSchema.FormMappingResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  # TODO write test cases
  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, params) do
    current_user = conn.assigns.current_user

    with %FormMapping{} = form_mapping <- Forms.get_form_mapping(current_user, params) do
      render(conn, "show.json", form_mapping: form_mapping)
    end
  end

  operation(:update,
    summary: "Update a form_mapping",
    description: "Update form_mapping API",
    parameters: [
      form_id: [in: :path, type: :string, description: "Form id", required: true],
      mapping_id: [in: :path, type: :string, description: "form_mapping id", required: true]
    ],
    request_body:
      {"FormMapping to be updated", "application/json", FormMappingSchema.FormMapping},
    responses: [
      ok: {"Ok", "application/json", FormMappingSchema.FormMappingResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

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
