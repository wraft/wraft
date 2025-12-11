defmodule WraftDocWeb.Api.V1.FormEntryController do
  @moduledoc """
  Controller for managing form entries
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    delete: "form_entry:delete",
    create: "form_entry:manage",
    index: "form_entry:show",
    show: "form_entry:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormEntry
  alias WraftDoc.Forms.FormPipeline

  tags(["Form Entries"])

  @doc """
  Show a specific form entry
  """
  operation(:show,
    summary: "Show a form entry",
    description: "Retrieve details of a specific form entry",
    parameters: [
      form_id: [in: :path, type: :string, description: "Form ID", required: true],
      id: [in: :path, type: :string, description: "Form Entry ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.FormEntry.FormEntryResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  # TODO Add tests for this
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, params) do
    current_user = conn.assigns.current_user

    with %FormEntry{} = form_entry <- Forms.show_form_entry(current_user, params) do
      render(conn, "form_entry.json", form_entry: form_entry)
    end
  end

  @doc """
  Create a new form entry
  """
  operation(:create,
    summary: "Create a form entry",
    description: "Create a new form entry and optionally trigger associated pipelines",
    parameters: [
      form_id: [in: :path, type: :string, description: "Form ID", required: true]
    ],
    request_body: {"Form Entry", "application/json", Schemas.FormEntry.FormEntryRequest},
    responses: [
      created: {"Created", "application/json", Schemas.FormEntry.FormEntryResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"pipeline_id" => pipeline_id} = params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.show_form(current_user, params["form_id"]),
         %FormPipeline{} <- Forms.get_form_pipeline(form, pipeline_id),
         {:ok, %FormEntry{data: data} = form_entry} <-
           Forms.create_form_entry(current_user, form, params),
         {:ok, trigger_response} <- Forms.trigger_pipeline(current_user, pipeline_id, data, 0) do
      render(conn, "form_entry.json", %{
        form_entry: form_entry,
        trigger_response: trigger_response
      })
    end
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.show_form(current_user, params["form_id"]),
         {:ok, %FormEntry{} = form_entry} <- Forms.create_form_entry(current_user, form, params),
         :ok <- Forms.trigger_pipelines(current_user, form, form_entry) do
      render(conn, "form_entry.json", form_entry: form_entry)
    end
  end

  @doc """
  List all form entries with pagination
  """
  operation(:index,
    summary: "List form entries",
    description: "Retrieve a paginated list of form entries",
    parameters: [
      form_id: [in: :path, type: :string, description: "Form ID", required: true],
      page: [in: :query, type: :integer, description: "Page number"],
      sort: [
        in: :query,
        type: :string,
        description: "Sort keys: inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.FormEntry.FormEntryIndex},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: form_entries,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Forms.form_entry_index(current_user, params) do
      render(conn, "index.json",
        form_entries: form_entries,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
