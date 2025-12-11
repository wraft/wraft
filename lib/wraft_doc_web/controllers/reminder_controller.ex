defmodule WraftDocWeb.Api.V1.ReminderController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Reminder
  alias WraftDoc.Documents.Reminders
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Reminder, as: ReminderSchema

  tags(["Reminders"])

  operation(:index,
    summary: "List all reminders",
    description: "Returns all reminders",
    operation_id: "list_document_reminders",
    parameters: [
      instance_id: [in: :query, type: :string, description: "Instance ID"],
      status: [in: :query, type: :string, description: "Reminder status, eg: pending, sent"],
      upcoming: [in: :query, type: :boolean, description: "Upcoming reminders"],
      start_date: [in: :query, type: :string, description: "Start date for upcoming reminders"],
      end_date: [in: :query, type: :string, description: "End date for upcoming reminders"],
      page: [in: :query, type: :string, description: "Page number"],
      sort: [
        in: :query,
        type: :string,
        description:
          "sort keys => inserted_at, inserted_at_desc, reminder_date, reminder_date_desc"
      ]
    ],
    responses: [
      ok: {"OK", "application/json", ReminderSchema.ReminderIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: reminders,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Reminders.reminders_index(current_user, params) do
      render(conn, "index.json",
        reminders: reminders,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Get a specific reminder",
    description: "Returns the details of a specific reminder",
    operation_id: "get_reminder",
    parameters: [
      content_id: [in: :path, type: :string, description: "Document ID", required: true],
      id: [in: :path, type: :string, description: "Reminder ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", ReminderSchema.Reminder},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"content_id" => document_id, "id" => reminder_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Reminder{} = reminder <- Reminders.get_reminder(instance, reminder_id) do
      render(conn, "reminder.json", reminder: reminder)
    end
  end

  operation(:create,
    summary: "Create a new reminder",
    description: "Creates a new reminder for a document",
    operation_id: "create_reminder",
    parameters: [
      content_id: [in: :path, type: :string, description: "Document ID", required: true]
    ],
    request_body: {"Reminder parameters", "application/json", ReminderSchema.ReminderRequest},
    responses: [
      created: {"Created", "application/json", ReminderSchema.Reminder},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"content_id" => document_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         {:ok, %Reminder{} = reminder} <- Reminders.add_reminder(current_user, instance, params) do
      render(conn, "create.json", reminder: reminder)
    end
  end

  operation(:update,
    summary: "Update a reminder",
    description: "Updates an existing reminder for a document",
    operation_id: "update_reminder",
    parameters: [
      content_id: [in: :path, type: :string, description: "Document ID", required: true],
      id: [in: :path, type: :string, description: "Reminder ID", required: true]
    ],
    request_body: {"Reminder parameters", "application/json", ReminderSchema.ReminderRequest},
    responses: [
      ok: {"OK", "application/json", ReminderSchema.Reminder},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"content_id" => document_id, "id" => reminder_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Reminder{} = reminder <- Reminders.get_reminder(instance, reminder_id),
         {:ok, %Reminder{} = updated_reminder} <- Reminders.update_reminder(reminder, params) do
      render(conn, "reminder.json", reminder: updated_reminder)
    end
  end

  operation(:delete,
    summary: "Delete a reminder",
    description: "Deletes an existing reminder",
    operation_id: "delete_reminder",
    parameters: [
      content_id: [in: :path, type: :string, description: "Document ID", required: true],
      id: [in: :path, type: :string, description: "Reminder ID", required: true]
    ],
    responses: [
      no_content: {"No Content", "application/json", ReminderSchema.Reminder},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"content_id" => document_id, "id" => reminder_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Reminder{} = reminder <- Reminders.get_reminder(instance, reminder_id),
         {:ok, reminder} <- Reminders.delete_reminder(reminder) do
      render(conn, "reminder.json", reminder: reminder)
    end
  end
end
