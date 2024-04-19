defmodule WraftDocWeb.Api.V1.FormEntryController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    delete: "form_entry:delete",
    create: "form_entry:create"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormEntry

  def swagger_definitions do
    %{
      FormEntryRequest:
        swagger_schema do
          title("Form Entries")
          description("A form entry")

          properties do
            data(Schema.ref(:FormFieldEntries))
          end

          example(%{
            data: [
              %{
                field_id: "0b214501-05be-4d58-a407-51fc763428cd",
                value: "sample@gmail.com"
              },
              %{
                field_id: "0b214501-05be-4d58-a407-51fc763428cd",
                value: "value"
              }
            ]
          })
        end,
      FormFieldEntries:
        swagger_schema do
          title("Form field entries array")
          description("List of form field entries")
          type(:array)
          items(Schema.ref(:FormFieldEntry))
        end,
      FormFieldEntry:
        swagger_schema do
          title("Form field entry")
          description("A single form field entry")

          properties do
            field_id(:string, "Field ID")
            value(:string, "Value")
          end

          example(%{
            field_id: "0b214501-05be-4d58-a407-51fc763428cd",
            value: "value"
          })
        end,
      FormEntryResponse:
        swagger_schema do
          title("Form Entry Response")
          description("Response for form entry")

          properties do
            info(:string, "Response Info")
          end

          example(%{
            info: "Success"
          })
        end
    }
  end

  @doc """
    Show form entry
  """
  swagger_path :show do
    get("/forms/{form_id}/entries/{id}")
    summary("Show a form entry")
    description("Show a form entry")

    parameters do
      form_id(:path, :string, "Form ID", required: true)
      id(:path, :string, "Form Entry ID", required: true)
    end

    response(200, "Ok", Schema.ref(:FormEntryResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  # TODO Add tests for this
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, params) do
    current_user = conn.assigns.current_user

    with %FormEntry{} = form_entry <- Forms.show_form_entry(current_user, params) do
      render(conn, "form_entry.json", form_entry: form_entry)
    end
  end

  @doc """
    Create form entry
  """
  swagger_path :create do
    post("/forms/{form_id}/entries")
    summary("Create a form entry")
    description("Create a form entry")

    parameters do
      form_id(:path, :string, "Form ID", required: true)
      form_entry(:body, Schema.ref(:FormEntryRequest), "Form Entry", required: true)
    end

    response(201, "Ok", Schema.ref(:FormEntryResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Form{} = form <- Forms.show_form(current_user, params["form_id"]),
         %FormEntry{} = form_entry <- Forms.create_form_entry(current_user, form, params) do
      render(conn, "form_entry.json", form_entry: form_entry)
    end
  end
end
