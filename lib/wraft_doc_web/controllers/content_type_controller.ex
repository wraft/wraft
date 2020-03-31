defmodule WraftDocWeb.Api.V1.ContentTypeController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.ContentType, Document.Layout, Enterprise, Enterprise.Flow}

  def swagger_definitions do
    %{
      ContentTypeRequest:
        swagger_schema do
          title("Content Type Request")
          description("Create content type request.")

          properties do
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description", required: true)
            fields(Schema.ref(:ContentTypeFieldRequests))
            layout_uuid(:string, "ID of the layout selected", required: true)
            flow_uuid(:string, "ID of the flow selected", required: true)
            color(:string, "Hex code of color")

            prefix(:string, "Prefix to be used for generating Unique ID for contents",
              required: true
            )
          end

          example(%{
            name: "Offer letter",
            description: "An offer letter",
            fields: [
              %{key: "position", field_type_id: "kjb14713132lkdac"},
              %{key: "name", field_type_id: "kjb2347mnsad"}
            ],
            layout_uuid: "1232148nb3478",
            flow_uuid: "234okjnskjb8234",
            prefix: "OFFLET",
            color: "#fff"
          })
        end,
      ContentTypeFieldRequest:
        swagger_schema do
          title("Content type field request")
          description("Data to be send to add fields to content type.")

          properties do
            key(:string, "Name of the field")
            field_type_id(:string, "ID of the field type")
          end

          example(%{
            key: "position",
            field_type_id: "asdlkne4781234123clk"
          })
        end,
      ContentTypeField:
        swagger_schema do
          title("Content type field in response")
          description("Content type field in respone.")

          properties do
            id(:string, "ID of content type field")
            name(:string, "Name of content type field")
            field_type(Schema.ref(:FieldType))
          end

          example(%{
            key: "position",
            field_type_id: "asdlkne4781234123clk"
          })
        end,
      ContentTypeFields:
        swagger_schema do
          title("Field response array")
          description("List of field type in response.")
          type(:array)
          items(Schema.ref(:ContentTypeField))
        end,
      ContentTypeFieldRequests:
        swagger_schema do
          title("Field request array")
          description("List of data to be send to add fields to content type.")
          type(:array)
          items(Schema.ref(:ContentTypeFieldRequest))
        end,
      ContentType:
        swagger_schema do
          title("Content Type")
          description("A Content Type.")

          properties do
            id(:string, "The ID of the content type", required: true)
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            color(:string, "Hex code of color")
            fields(Schema.ref(:ContentTypeFields))
            prefix(:string, "Prefix to be used for generating Unique ID for contents")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Offer letter",
            description: "An offer letter",
            fields: [
              %{key: "position", field_type_id: "kjb14713132lkdac"},
              %{key: "name", field_type_id: "kjb2347mnsad"}
            ],
            prefix: "OFFLET",
            color: "#fffff",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentTypeAndLayout:
        swagger_schema do
          title("Content Type and Layout")
          description("Content Type to be used for the generation of a document and its layout.")

          properties do
            id(:string, "The ID of the content type", required: true)
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            fields(Schema.ref(:ContentTypeFields))
            prefix(:string, "Prefix to be used for generating Unique ID for contents")
            color(:string, "Hex code of color")
            layout(Schema.ref(:Layout))
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Offer letter",
            description: "An offer letter",
            fields: [
              %{key: "position", field_type_id: "kjb14713132lkdac"},
              %{key: "name", field_type_id: "kjb2347mnsad"}
            ],
            prefix: "OFFLET",
            color: "#fffff",
            layout: %{
              id: "1232148nb3478",
              name: "Official Letter",
              description: "An official letter",
              width: 40.0,
              height: 20.0,
              unit: "cm",
              slug: "Pandoc",
              slug_file: "/letter.zip",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentTypeAndLayoutAndFlow:
        swagger_schema do
          title("Content Type, Layout and its flow")

          description(
            "Content Type to be used for the generation of a document, its layout and flow."
          )

          properties do
            id(:string, "The ID of the content type", required: true)
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            fields(Schema.ref(:ContentTypeFields))
            prefix(:string, "Prefix to be used for generating Unique ID for contents")
            color(:string, "Hex code of color")
            layout(Schema.ref(:Layout))
            flow(Schema.ref(:Flow))
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Offer letter",
            description: "An offer letter",
            fields: [
              %{key: "position", field_type_id: "kjb14713132lkdac"},
              %{key: "name", field_type_id: "kjb2347mnsad"}
            ],
            prefix: "OFFLET",
            color: "#fffff",
            layout: %{
              id: "1232148nb3478",
              name: "Official Letter",
              description: "An official letter",
              width: 40.0,
              height: 20.0,
              unit: "cm",
              slug: "Pandoc",
              slug_file: "/letter.zip",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            flow: %{
              id: "1232148nb3478",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentTypesAndLayoutsAndFlows:
        swagger_schema do
          title("Content Types and their Layouts and flow")
          description("All content types that have been created and their layouts and flow")
          type(:array)
          items(Schema.ref(:ContentTypeAndLayoutAndFlow))
        end,
      ContentTypeAndLayoutAndFlowAndStates:
        swagger_schema do
          title("Content Type, Layout, Flow and states")

          description(
            "Content Type to be used for the generation of a document, its layout, flow and states."
          )

          properties do
            id(:string, "The ID of the content type", required: true)
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            fields(Schema.ref(:ContentTypeFields))
            prefix(:string, "Prefix to be used for generating Unique ID for contents")
            color(:string, "Hex code of color")
            layout(Schema.ref(:Layout))
            flow(Schema.ref(:FlowAndStatesWithoutCreator))
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Offer letter",
            description: "An offer letter",
            fields: [
              %{key: "position", field_type_id: "kjb14713132lkdac"},
              %{key: "name", field_type_id: "kjb2347mnsad"}
            ],
            prefix: "OFFLET",
            color: "#fffff",
            layout: %{
              id: "1232148nb3478",
              name: "Official Letter",
              description: "An official letter",
              width: 40.0,
              height: 20.0,
              unit: "cm",
              slug: "Pandoc",
              slug_file: "/letter.zip",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            flow: %{
              id: "1232148nb3478",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z",
              states: [
                %{
                  id: "1232148nb3478",
                  state: "published",
                  order: 1
                }
              ]
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ShowContentType:
        swagger_schema do
          title("Content Type and all its details")
          description("API to show a content type and all its details")

          properties do
            content_type(Schema.ref(:ContentTypeAndLayoutAndFlowAndStates))
            creator(Schema.ref(:User))
          end

          example(%{
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              fields: [
                %{key: "position", field_type_id: "kjb14713132lkdac"},
                %{key: "name", field_type_id: "kjb2347mnsad"}
              ],
              prefix: "OFFLET",
              color: "#fffff",
              flow: %{
                id: "1232148nb3478",
                name: "Flow 1",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z",
                states: [
                  %{
                    id: "1232148nb3478",
                    state: "published",
                    order: 1
                  }
                ]
              },
              layout: %{
                id: "1232148nb3478",
                name: "Official Letter",
                description: "An official letter",
                width: 40.0,
                height: 20.0,
                unit: "cm",
                slug: "Pandoc",
                slug_file: "/letter.zip",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              },
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ContentTypesIndex:
        swagger_schema do
          properties do
            content_types(Schema.ref(:ContentTypesAndLayoutsAndFlows))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            content_types: [
              %{
                content_type: %{
                  id: "1232148nb3478",
                  name: "Offer letter",
                  description: "An offer letter",
                  fields: [
                    %{key: "position", field_type_id: "kjb14713132lkdac"},
                    %{key: "name", field_type_id: "kjb2347mnsad"}
                  ],
                  prefix: "OFFLET",
                  color: "#fffff",
                  flow: %{
                    id: "1232148nb3478",
                    name: "Flow 1",
                    updated_at: "2020-01-21T14:00:00Z",
                    inserted_at: "2020-02-21T14:00:00Z"
                  },
                  layout: %{
                    id: "1232148nb3478",
                    name: "Official Letter",
                    description: "An official letter",
                    width: 40.0,
                    height: 20.0,
                    unit: "cm",
                    slug: "Pandoc",
                    slug_file: "/letter.zip",
                    updated_at: "2020-01-21T14:00:00Z",
                    inserted_at: "2020-02-21T14:00:00Z"
                  },
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                creator: %{
                  id: "1232148nb3478",
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
        end
    }
  end

  @doc """
  Create a content type.
  """
  swagger_path :create do
    post("/content_types")
    summary("Create content type")
    description("Create content type API")

    parameters do
      content_type(:body, Schema.ref(:ContentTypeRequest), "Content Type to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:ContentTypeAndLayoutAndFlow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"layout_uuid" => layout_uuid, "flow_uuid" => flow_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Document.get_layout(layout_uuid),
         %Flow{} = flow <- Enterprise.get_flow(flow_uuid),
         %ContentType{} = content_type <-
           Document.create_content_type(current_user, layout, flow, params) do
      conn
      |> render(:create, content_type: content_type)
    end
  end

  @doc """
  Content Type index.
  """
  swagger_path :index do
    get("/content_types")
    summary("Content Type index")
    description("API to get the list of all content types created so far")
    parameter(:page, :query, :string, "Page number")
    response(200, "Ok", Schema.ref(:ContentTypesIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: content_types,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.content_type_index(current_user, params) do
      conn
      |> render("index.json",
        content_types: content_types,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show a Content Type.
  """
  swagger_path :show do
    get("/content_types/{id}")
    summary("Show a Content Type")
    description("API to show details of a content type")

    parameters do
      id(:path, :string, "content type id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContentType))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => uuid}) do
    with %ContentType{} = content_type <- Document.show_content_type(uuid) do
      conn
      |> render("show.json", content_type: content_type)
    end
  end

  @doc """
  Update a Content Type.
  """
  swagger_path :update do
    put("/content_types/{id}")
    summary("Update a Content Type")
    description("API to update a content type")

    parameters do
      id(:path, :string, "content type id", required: true)
      layout(:body, Schema.ref(:ContentTypeRequest), "Content Type to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContentType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %ContentType{} = content_type <- Document.get_content_type(uuid),
         %ContentType{} = content_type <- Document.update_content_type(content_type, params) do
      conn
      |> render("show.json", content_type: content_type)
    end
  end

  @doc """
  Delete a Content Type.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/content_types/{id}")
    summary("Delete a Content Type")
    description("API to delete a content type")

    parameters do
      id(:path, :string, "content type id", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %ContentType{} = content_type <- Document.get_content_type(uuid),
         {:ok, %ContentType{}} <- Document.delete_content_type(content_type) do
      conn
      |> render("content_type.json", content_type: content_type)
    end
  end
end
