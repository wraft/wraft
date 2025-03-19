defmodule WraftDocWeb.Api.V1.ContractReminderController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Documents.ContractReminders
  alias WraftDocWeb.Api.V1.ContractReminderView
  alias WraftDocWeb.Router.Helpers, as: Routes

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      ReminderRequest:
        swagger_schema do
          title("Reminder Request")
          description("A reminder to be created or updated for a contract")

          properties do
            reminder_date(:string, "Date when reminder should be triggered", format: "date", required: true)
            message(:string, "Reminder message content", required: true)
            notification_type(:string, "Type of notification to send: 'email', 'in_app', or 'both'", required: true)
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
            instance_id(:string, "Contract instance UUID", format: "uuid")
            reminder_date(:string, "Date when reminder should be triggered", format: "date")
            status(:string, "Current status of the reminder: 'pending' or 'sent'")
            message(:string, "Reminder message content")
            notification_type(:string, "Type of notification to send: 'email', 'in_app', or 'both'")
            recipients(array(:string), "List of recipient user IDs")
            manual_date(:boolean, "Whether this is a manually scheduled reminder")
            sent_at(:string, "When the reminder was sent", format: "ISO-8601")
            inserted_at(:string, "When the reminder was created", format: "ISO-8601")
            updated_at(:string, "When the reminder was last updated", format: "ISO-8601")
          end

          example(%{
            id: "2a4d5c6f-8e9f-4a1b-8c5d-9e7f4a3b2c1d",
            instance_id: "3b2a1d4c-5e6f-7a8b-9c1d-2e3f4a5b6c7d",
            reminder_date: "2023-12-31",
            status: "pending",
            message: "Contract renewal due soon",
            notification_type: "both",
            recipients: ["user-123", "user-456"],
            manual_date: true,
            sent_at: nil,
            inserted_at: "2023-06-15T14:00:00Z",
            updated_at: "2023-06-15T14:00:00Z"
          })
        end
    }
  end

  @doc """
  Get all reminders for a contract
  """
  swagger_path :index do
    get("/contracts/{instance_id}/reminders")
    summary("List all reminders for a contract")
    description("Returns all reminders associated with the specified contract")
    operation_id("list_contract_reminders")

    parameters do
      instance_id(:path, :string, "Contract instance ID", required: true)
    end

    response(200, "OK", Schema.array(:Reminder))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def index(conn, %{"instance_id" => instance_id}) do
    reminders = ContractReminders.list_reminders(instance_id)
    conn
    |> put_view(ContractReminderView)
    |> render("index.json", reminders: reminders)
  end

  @doc """
  Get a specific reminder
  """
  swagger_path :show do
    get("/reminders/{id}")
    summary("Get a specific reminder")
    description("Returns the details of a specific reminder")
    operation_id("get_reminder")

    parameters do
      id(:path, :string, "Reminder ID", required: true)
    end

    response(200, "OK", Schema.ref(:Reminder))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => id}) do
    with {:ok, reminder} <- ContractReminders.get_reminder(id) do
      conn
      |> put_view(ContractReminderView)
      |> render("show.json", reminder: reminder)
    end
  end

  @doc """
  Create a new reminder for a contract
  """
  swagger_path :create do
    post("/contracts/{instance_id}/reminders")
    summary("Create a new reminder")
    description("Creates a new reminder for a contract")
    operation_id("create_reminder")

    parameters do
      instance_id(:path, :string, "Contract instance ID", required: true)
      reminder(:body, Schema.ref(:ReminderRequest), "Reminder parameters", required: true)
    end

    response(201, "Created", Schema.ref(:Reminder))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def create(conn, %{"instance_id" => instance_id, "reminder" => reminder_params}) do
    with {:ok, reminder} <- ContractReminders.add_reminder(instance_id, reminder_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.v1_contract_reminder_path(conn, :show, instance_id, reminder.id)
      )
      |> put_view(ContractReminderView)
      |> render("show.json", reminder: reminder)
    end
  end

  @doc """
  Update an existing reminder
  """
  swagger_path :update do
    put("/contracts/{instance_id}/reminders/{id}")
    summary("Update a reminder")
    description("Updates an existing reminder for a contract")
    operation_id("update_reminder")

    parameters do
      instance_id(:path, :string, "Contract instance ID", required: true)
      id(:path, :string, "Reminder ID", required: true)
      reminder(:body, Schema.ref(:ReminderRequest), "Reminder parameters", required: true)
    end

    response(200, "OK", Schema.ref(:Reminder))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def update(conn, %{
        "instance_id" => instance_id,
        "id" => reminder_id,
        "reminder" => reminder_params
      }) do
    with {:ok, reminder} <-
           ContractReminders.update_reminder(instance_id, reminder_id, reminder_params) do
      conn
      |> put_view(ContractReminderView)
      |> render("show.json", reminder: reminder)
    end
  end

  @doc """
  Delete a reminder
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/contracts/{instance_id}/reminders/{id}")
    summary("Delete a reminder")
    description("Deletes an existing reminder")
    operation_id("delete_reminder")

    parameters do
      instance_id(:path, :string, "Contract instance ID", required: true)
      id(:path, :string, "Reminder ID", required: true)
    end

    response(204, "No Content")
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete(conn, %{"instance_id" => instance_id, "id" => reminder_id}) do
    with {:ok, _reminder} <- ContractReminders.delete_reminder(instance_id, reminder_id) do
      send_resp(conn, :no_content, "")
    end
  end
end 