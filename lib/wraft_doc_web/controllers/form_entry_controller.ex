defmodule WraftDocWeb.Api.V1.FormEntryController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

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
            form_id(:string, "Form ID")
            id(:string, "Form Entry ID")
            inserted_at(:string, "When was the form entry inserted", format: "ISO-8601")
            status(:string, "Status of the form entry")
            updated_at(:string, "When was the form entry last updated", format: "ISO-8601")
            user_id(:string, "User ID")
            data(Schema.ref(:FormFieldEntries))
          end

          example(%{
            data: %{
              "3a266577-c717-4fba-b465-ec7b89301445": "sample@gmail.com",
              "4adcab31-fabd-4243-9eee-3a755407f8d3": "value"
            },
            form_id: "aa18afe1-3383-4653-bc0e-505ec3bbfc19",
            id: "f507ca98-9848-49af-89f8-a21f12202ec0",
            inserted_at: "2024-04-17T07:10:17",
            status: "draft",
            updated_at: "2024-04-17T07:10:17",
            user_id: "af2cf1c6-f342-4042-8425-6346e9fd6c44"
          })
        end,
      FormEntryIndex:
        swagger_schema do
          title("Form Entry Index Response")
          description("Response for form entry index")

          properties do
            entries(Schema.array(:FormEntryResponse))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            entries: [
              %{
                data: %{
                  "3a266577-c717-4fba-b465-ec7b89301445": "sample@gmail.com",
                  "4adcab31-fabd-4243-9eee-3a755407f8d3": "value"
                },
                form_id: "aa18afe1-3383-4653-bc0e-505ec3bbfc19",
                id: "f507ca98-9848-49af-89f8-a21f12202ec0",
                inserted_at: "2024-04-17T07:10:17",
                status: "draft",
                updated_at: "2024-04-17T07:10:17",
                user_id: "af2cf1c6-f342-4042-8425-6346e9fd6c44"
              },
              %{
                data: %{
                  "3a266577-c717-4fba-b465-ec7b89301446": "sample2@gmail.com",
                  "4adcab31-fabd-4243-9eee-3a755407f8d4": "value2"
                },
                form_id: "aa18afe1-3383-4653-bc0e-505ec3bbfc20",
                id: "f507ca98-9848-49af-89f8-a21f12202ec1",
                inserted_at: "2024-04-17T07:10:18",
                status: "submitted",
                updated_at: "2024-04-17T07:10:18",
                user_id: "af2cf1c6-f342-4042-8425-6346e9fd6c45"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
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

  @doc """
    List of all form entries.
  """
  swagger_path :index do
    get("/forms/{form_id}/entries")
    summary("List of form entries")
    description("List of form entries")

    parameters do
      form_id(:path, :string, "Form ID", required: true)
      page(:query, :integer, "Page number", required: false)
      sort(:query, :string, "Sort Keys => inserted_at, inserted_at_desc")
    end

    response(200, "Ok", Schema.ref(:FormEntryResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

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
