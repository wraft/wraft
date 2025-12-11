defmodule WraftDocWeb.Api.V1.FormController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug(WraftDocWeb.Plug.AddActionLog)

  plug(WraftDocWeb.Plug.Authorized,
    create: "form:manage",
    index: "form:show",
    show: "form:show",
    update: "form:manage",
    delete: "form:delete",
    align_fields: "form:manage"
  )

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Form, as: FormSchema

  tags(["Forms"])

  operation(:create,
    summary: "Create wraft form",
    description: "Create wraft form API",
    request_body: {"Form Type to be created", "application/json", FormSchema.FormRequest},
    responses: [
      ok: {"Ok", "application/json", FormSchema.Form},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.create(current_user, params) do
      Typesense.create_document(form)
      render(conn, "form.json", form: form)
    end
  end

  operation(:index,
    summary: "Form Index",
    description: "API to get the list of forms within the user's organisation.",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Name"],
      sort: [
        in: :query,
        type: :string,
        description: "sort keys => name, name_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", FormSchema.FormsIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: forms,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Forms.form_index(current_user, params) do
      render(conn, "index.json",
        forms: forms,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:status_update,
    summary: "Update form status",
    description: "API to update the status of the form",
    parameters: [
      id: [in: :path, type: :string, description: "form id", required: true]
    ],
    request_body: {"New form status", "application/json", FormSchema.FormStatusUpdateRequest},
    responses: [
      ok: {"Ok", "application/json", FormSchema.SimpleForm},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec status_update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def status_update(conn, %{"id" => form_id} = params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.get_form(current_user, form_id),
         {:ok, %Form{} = form} <- Forms.update_status(form, params) do
      render(conn, "simple_form.json", form: form)
    end
  end

  operation(:update,
    summary: "Update a wraft form",
    description: "Update wraft form API",
    parameters: [
      id: [in: :path, type: :string, description: "form id", required: true]
    ],
    request_body: {"Form to be updated", "application/json", FormSchema.UpdateFormRequest},
    responses: [
      ok: {"Ok", "application/json", FormSchema.Form},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => form_id} = params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.get_form(current_user, form_id),
         %Form{} = form <- Forms.update_form(form, params) do
      Typesense.update_document(form)
      render(conn, "form.json", form: form)
    end
  end

  operation(:show,
    summary: "Show a wraft form",
    description: "Show a wraft form API",
    parameters: [
      id: [in: :path, type: :string, description: "form id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FormSchema.Form},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => form_id}) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.show_form(current_user, form_id) do
      render(conn, "form.json", form: form)
    end
  end

  operation(:delete,
    summary: "Delete a wraft form",
    description: "API to delete a wraft form",
    parameters: [
      id: [in: :path, type: :string, description: "form id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FormSchema.Form},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => form_id}) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.show_form(current_user, form_id),
         %Form{} <- Forms.delete_form(form) do
      Typesense.delete_document(form, "form")
      render(conn, "simple_form.json", form: form)
    end
  end

  operation(:align_fields,
    summary: "Update form fields order",
    description: "Api to update order of form fields",
    parameters: [
      id: [in: :path, type: :string, description: "Form id", required: true]
    ],
    request_body:
      {"Form and field IDs with order to be updated", "application/json",
       FormSchema.AlignFormFieldsRequest},
    responses: [
      ok: {"Ok", "application/json", FormSchema.Form},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec align_fields(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def align_fields(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.show_form(current_user, id),
         %Form{} = form <- Forms.align_fields(form, params) do
      render(conn, "form.json", form: form)
    end
  end
end
