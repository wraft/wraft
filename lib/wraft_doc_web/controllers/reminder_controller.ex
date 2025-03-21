defmodule WraftDocWeb.Api.V1.ReminderController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    show: "reminder:show",
    index: "reminder:show",
    create: "reminder:manage",
    update: "reminder:manage",
    delete: "reminder:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Reminder
  alias WraftDoc.Documents.Reminders

  def swagger_definitions do
    %{
      ReminderRequest:
        swagger_schema do
          title("Reminder Request")
          description("A reminder to be created or updated for a contract")

          properties do
            reminder_date(:string, "Date when reminder should be triggered",
              format: "date",
              required: true
            )

            message(:string, "Reminder message content", required: true)

            notification_type(
              :string,
              "Type of notification to send: 'email', 'in_app', or 'both'",
              required: true
            )

            recipients(array(:string), "List of recipient user IDs")
            manual_date(:boolean, "Whether this is a manually scheduled reminder")
          end

          example(%{
            reminder_date: "2023-12-31",
            message: "Contract renewal due soon",
            notification_type: "both",
            recipients: ["user-123", "user-456"],
            manual_date: true
          })
        end,
      Reminder:
        swagger_schema do
          title("Reminder")
          description("A contract reminder")

          properties do
            id(:string, "Reminder UUID", format: "uuid")
            content_id(:string, "Document ID", format: "uuid")
            reminder_date(:string, "Date when reminder should be triggered", format: "date")
            status(:string, "Current status of the reminder: 'pending' or 'sent'")
            message(:string, "Reminder message content")

            notification_type(
              :string,
              "Type of notification to send: 'email', 'in_app', or 'both'"
            )

            recipients(array(:string), "List of recipient user IDs")
            manual_date(:boolean, "Whether this is a manually scheduled reminder")
            sent_at(:string, "When the reminder was sent", format: "ISO-8601")
            inserted_at(:string, "When the reminder was created", format: "ISO-8601")
            updated_at(:string, "When the reminder was last updated", format: "ISO-8601")
          end

          example(%{
            id: "2a4d5c6f-8e9f-4a1b-8c5d-9e7f4a3b2c1d",
            content_id: "3b2a1d4c-5e6f-7a8b-9c1d-2e3f4a5b6c7d",
            reminder_date: "2023-12-31",
            status: "pending",
            message: "Contract renewal due soon",
            notification_type: "both",
            recipients: [
              "238ed26a-a06d-4305-b01b-6959500e3606",
              "bc3c3a7f-ffce-475a-be7c-e034cca94b09"
            ],
            manual_date: true,
            sent_at: nil,
            inserted_at: "2023-06-15T14:00:00Z",
            updated_at: "2023-06-15T14:00:00Z"
          })
        end
    }
  end

  @doc """
  Get all reminders for a document
  """
  swagger_path :index do
    get("/contents/{content_id}/reminders")
    summary("List all reminders for a document")
    description("Returns all reminders associated with the specified document")
    operation_id("list_document_reminders")

    parameters do
      content_id(:path, :string, "Document ID", required: true)
    end

    response(200, "OK", Schema.array(:Reminder))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"content_id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         reminders <- Reminders.list_reminders(instance) do
      render(conn, "index.json", reminders: reminders)
    end
  end

  @doc """
  Get a specific reminder
  """
  swagger_path :show do
    get("/contents/{content_id}/reminders/{id}")
    summary("Get a specific reminder")
    description("Returns the details of a specific reminder")
    operation_id("get_reminder")

    parameters do
      content_id(:path, :string, "Document ID", required: true)
      id(:path, :string, "Reminder ID", required: true)
    end

    response(200, "OK", Schema.ref(:Reminder))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"content_id" => document_id, "id" => reminder_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Reminder{} = reminder <- Reminders.get_reminder(instance, reminder_id) do
      render(conn, "reminder.json", reminder: reminder)
    end
  end

  @doc """
  Create a new reminder for a contract
  """
  swagger_path :create do
    post("/contents/{content_id}/reminders")
    summary("Create a new reminder")
    description("Creates a new reminder for a document")
    operation_id("create_reminder")

    parameters do
      content_id(:path, :string, "Document ID", required: true)
      reminder(:body, Schema.ref(:ReminderRequest), "Reminder parameters", required: true)
    end

    response(201, "Created", Schema.ref(:Reminder))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"content_id" => document_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         {:ok, %Reminder{} = reminder} <- Reminders.add_reminder(current_user, instance, params) do
      Reminders.set_reminder_in_valkey(instance, reminder)
      render(conn, "create.json", reminder: reminder)
    end
  end

  @doc """
  Update an existing reminder
  """
  swagger_path :update do
    put("/contents/{content_id}/reminders/{id}")
    summary("Update a reminder")
    description("Updates an existing reminder for a document")
    operation_id("update_reminder")

    parameters do
      content_id(:path, :string, "Document ID", required: true)
      id(:path, :string, "Reminder ID", required: true)
      reminder(:body, Schema.ref(:ReminderRequest), "Reminder parameters", required: true)
    end

    response(200, "OK", Schema.ref(:Reminder))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"content_id" => document_id, "id" => reminder_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Reminder{} = reminder <- Reminders.get_reminder(instance, reminder_id),
         {:ok, %Reminder{} = updated_reminder} <- Reminders.update_reminder(reminder, params) do
      Reminders.set_reminder_in_valkey(instance, reminder)
      render(conn, "reminder.json", reminder: updated_reminder)
    end
  end

  @doc """
  Delete a reminder
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/contents/{content_id}/reminders/{id}")
    summary("Delete a reminder")
    description("Deletes an existing reminder")
    operation_id("delete_reminder")

    parameters do
      content_id(:path, :string, "Document ID", required: true)
      id(:path, :string, "Reminder ID", required: true)
    end

    response(204, "No Content")
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete(conn, %{"content_id" => document_id, "id" => reminder_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Reminder{} = reminder <- Reminders.get_reminder(instance, reminder_id),
         {:ok, reminder} <- Reminders.delete_reminder(reminder) do
      Reminders.delete_reminder_in_valkey(instance, reminder)
      render(conn, "reminder.json", reminder: reminder)
    end
  end
end
