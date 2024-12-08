defmodule WraftDocWeb.Api.V1.InstanceController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    index: "instance:show",
    all_contents: "instance:show",
    show: "instance:show",
    update: "instance:manage",
    delete: "instance:delete",
    build: "instance:manage",
    state_update: "instance:manage",
    lock_unlock: "instance:lock",
    search: "instance:show",
    change: "instance:show",
    approve: "instance:review",
    reject: "instance:review"

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  alias WraftDoc.Account
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Client.Minio.DownloadError
  alias WraftDoc.Document
  alias WraftDoc.Document.ContentCollaboration
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.Instance
  alias WraftDoc.Document.Layout
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow.State

  alias WraftDocWeb.Api.V1.InstanceVersionView

  def swagger_definitions do
    %{
      Content:
        swagger_schema do
          title("Content")
          description("A content, which is then used to generate the out files.")

          properties do
            id(:string, "The ID of the content", required: true)
            instance_id(:string, "A unique ID generated for the content")
            raw(:string, "Raw data of the content")
            serialized(:map, "Serialized data of the content")
            build(:string, "URL of the build document")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            instance_id: "OFFL01",
            raw: "Content",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            build: "/uploads/OFFL01/OFFL01-v1.pdf",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      InstanceApprovals:
        swagger_schema do
          title("InstanceApprovals")
          description("Get list of pending approvals for current user")

          example(%{
            page_number: 1,
            pending_approvals: [
              %{
                content: %{
                  id: "12b7654e-87bd-4857-9ae1-183584db1a6c",
                  inserted_at: "2024-03-05T10:31:39",
                  instance_id: "ABCD0004",
                  next_state: "Publish",
                  previous_state: "null",
                  raw: "body here\n\nsome document here",
                  serialized: %{
                    body: "body here\n\nsome document here",
                    serialized: "",
                    title: "Raj"
                  },
                  updated_at: "2024-03-05T10:31:39"
                },
                creator: %{
                  id: "b6fb1848-1bd3-4461-a6e6-0d0aeec9c5ef",
                  name: "name",
                  profile_pic: "http://localhost:9000/wraft/uploads/images/avatar.png"
                },
                state: %{
                  id: "31c7d9d5-bbc2-45db-b21a-9a64ad501548",
                  inserted_at: "2024-03-05T10:17:31",
                  order: 1,
                  state: "Draft",
                  updated_at: "2024-03-05T10:17:31"
                }
              }
            ],
            total_entries: 1,
            total_pages: 1
          })
        end,
      ContentRequest:
        swagger_schema do
          title("Content Request")
          description("Content creation request")

          properties do
            raw(:string, "Content raw data", required: true)
            serialized(:string, "Content serialized data")
          end

          example(%{
            raw: "Content data",
            serialized: %{title: "Title of the content", body: "Body of the content"}
          })
        end,
      ContentUpdateRequest:
        swagger_schema do
          title("Content update Request")
          description("Content updation request")

          properties do
            raw(:string, "Content raw data", required: true)
            serialized(:string, "Content serialized data")
            naration(:string, "Naration for updation")
          end

          example(%{
            raw: "Content data",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            naration: "Revision by manager"
          })
        end,
      ContentStateUpdateRequest:
        swagger_schema do
          title("Content state update Request")
          description("Content state update request")

          properties do
            state_id(:string, "state id", required: true)
          end

          example(%{
            state_id: "kjb12389k23eyg"
          })
        end,
      ContentAndContentTypeAndState:
        swagger_schema do
          title("Content and its Content Type")
          description("A content and its content type")

          properties do
            content(Schema.ref(:Content))
            content_type(Schema.ref(:ContentTypeWithoutFields))
            state(Schema.ref(:State))
          end

          example(%{
            content: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            state: %{
              id: "1232148nb3478",
              state: "published",
              order: 1,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ShowContent:
        swagger_schema do
          title("Content and its details")
          description("A content and all its details")

          properties do
            content(Schema.ref(:Content))
            content_type(Schema.ref(:ContentTypeAndLayout))
            state(Schema.ref(:State))
            creator(Schema.ref(:User))
          end

          example(%{
            content: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              fields: %{
                name: "string",
                position: "string",
                joining_date: "date",
                approved_by: "string"
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
            state: %{
              id: "1232148nb3478",
              state: "published",
              order: 1,
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
      ContentsAndContentTypeAndState:
        swagger_schema do
          title("Instances, their content types and states")
          description("IInstances and all its details except creator.")
          type(:array)
          items(Schema.ref(:ContentAndContentTypeAndState))
        end,
      ContentsIndex:
        swagger_schema do
          properties do
            contents(Schema.ref(:ContentsAndContentTypeAndState))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            contents: [
              %{
                content: %{
                  id: "1232148nb3478",
                  instance_id: "OFFL01",
                  raw: "Content",
                  serialized: %{title: "Title of the content", body: "Body of the content"},
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                content_type: %{
                  id: "1232148nb3478",
                  name: "Offer letter",
                  description: "An offer letter",
                  fields: %{
                    name: "string",
                    position: "string",
                    joining_date: "date",
                    approved_by: "string"
                  },
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                state: %{
                  id: "1232148nb3478",
                  state: "published",
                  order: 1,
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                vendor: %{
                  name: "Vos Services",
                  email: "serv@vosmail.com",
                  phone: "98565262262",
                  address: "rose boru, hourbures",
                  gstin: "32ADF22SDD2DFS32SDF",
                  reg_no: "ASD21122",
                  contact_person: "vikas abu"
                }
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end,
      Vendor:
        swagger_schema do
          title("Vendor")
          description("A Vendor")

          properties do
            name(:string, "Vendors name")
            email(:string, "Vendors email")
            phone(:string, "Phone number")
            address(:string, "The Address of the vendor")
            gstin(:string, "The Gstin of the vendor")
            reg_no(:string, "The RegNo of the vendor")

            contact_person(:string, "The ContactPerson of the vendor")
          end

          example(%{
            name: "Vos Services",
            email: "serv@vosmail.com",
            phone: "98565262262",
            address: "rose boru, hourbures",
            gstin: "32ADF22SDD2DFS32SDF",
            reg_no: "ASD21122",
            contact_person: "vikas abu"
          })
        end,
      LockUnlockRequest:
        swagger_schema do
          title("Lock unlock request")
          description("request to lock or unlock")

          properties do
            editable(:boolean, "Editable", required: true)
          end

          example(%{
            editable: true
          })
        end,
      Change:
        swagger_schema do
          title("List of changes")
          description("Lists the chenges on a version")

          properties do
            ins(:array)
            del(:array)
          end

          example(%{
            ins: ["testing version succesufll"],
            del: ["testing version"]
          })
        end,
      BuildRequest:
        swagger_schema do
          title("Build request")
          description("Request to build a document")

          properties do
            naration(:string, "Naration for this version")
          end

          example(%{
            naration: "New year edition"
          })
        end,
      ContentEmailResponse:
        swagger_schema do
          title("Email sent response")
          description("Response for document instance email sent")

          properties do
            info(:string, "Info")
          end

          example(%{
            info: "Email sent successfully"
          })
        end,
      DocumentInstanceMailer:
        swagger_schema do
          title("Document Instance Email")
          description("Api to send email for a given document instance")

          properties do
            email(:string, "Email", required: true)
            subject(:string, "Subject", required: true)
            message(:string, "Message", required: true)
            cc(Schema.array(:string), "Emails")
          end

          example(%{
            "email" => "example@example.com",
            "subject" => "Subject of the email",
            "message" => "Body of the email",
            "cc" => ["cc1@example.com", "cc2@example.com"]
          })
        end,
      ShareDocumentRequest:
        swagger_schema do
          title("Share document request")
          description("Request to share a document")

          properties do
            email(:string, "Email", required: true)
            role(:string, "Role", required: true, enum: ["suggestor", "viewer"])
          end

          example(%{
            "email" => "example@example.com",
            "role" => "suggestor"
          })
        end,
      VerifyDocumentInviteTokenResponse:
        swagger_schema do
          title("Verify document invite token response")
          description("Response for document invite token verification")

          properties do
            info(:string, "Info")
          end

          example(%{
            info: "Invite token verified successfully"
          })
        end
    }
  end

  @doc """
  Create an instance.
  """
  swagger_path :create do
    post("/content_types/{c_type_id}/contents")
    summary("Create a content")
    description("Create content API")

    parameters do
      c_type_id(:path, :string, "content type id", required: true)
      content(:body, Schema.ref(:ContentRequest), "Content to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentAndContentTypeAndState))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(
        conn,
        %{"c_type_id" => c_type_id} = params
      ) do
    current_user = conn.assigns[:current_user]
    type = Instance.types()[:normal]
    params = Map.put(params, "type", type)

    with %ContentType{} = c_type <- Document.show_content_type(current_user, c_type_id),
         %Instance{} = content <-
           Document.create_instance(current_user, c_type, params) do
      Logger.info("Create content success")
      render(conn, :create, content: content)
    else
      error ->
        Logger.error("Create content failed", error: error)
        error
    end
  end

  @doc """
  Instance index.
  """
  swagger_path :index do
    get("/content_types/{c_type_id}/contents")
    summary("Instance index")
    description("API to get the list of all instances created so far under a content type")

    parameters do
      c_type_id(:path, :string, "ID of the content type", required: true)
      page(:query, :string, "Page number")
      instance_id(:query, :string, "Instance ID")
      creator_id(:query, :string, "Creator ID")

      sort(
        :query,
        :string,
        "sort keys => instance_id, instance_id_desc, inserted_at, inserted_at_desc"
      )
    end

    response(200, "Ok", Schema.ref(:ContentsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"c_type_id" => c_type_id} = params) do
    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_index(c_type_id, params) do
      render(conn, "index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :list_pending_approvals do
    get("/users/list_pending_approvals")
    summary("List pending approvals")
    description("API to get the list of pending approvals for current user")

    response(200, "Ok", Schema.ref(:InstanceApprovals))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def list_pending_approvals(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.list_pending_approvals(current_user, params) do
      render(conn, "approvals_index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  All instances.
  """
  swagger_path :all_contents do
    get("/contents")
    summary("All instances")
    description("API to get the list of all instances created so far under an organisation")

    parameters do
      page(:query, :string, "Page number")
      instance_id(:query, :string, "Instance ID")
      content_type_name(:query, :string, "Content Type name")
      creator_id(:query, :string, "Creator ID")
      state(:query, :string, "State, eg: published, draft, review")
      document_instance_title(:query, :string, "Document instance title")

      sort(
        :query,
        :string,
        "sort keys => instance_id, instance_id_desc, inserted_at, inserted_at_desc"
      )
    end

    response(200, "Ok", Schema.ref(:ContentsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec all_contents(Plug.Conn.t(), map) :: Plug.Conn.t()
  def all_contents(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_index_of_an_organisation(current_user, params) do
      render(conn, "index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show instance.
  """
  swagger_path :show do
    get("/contents/{id}")
    summary("Show an instance")
    description("API to get all details of an instance")

    parameters do
      id(:path, :string, "ID of the instance", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => instance_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Document.show_instance(instance_id, current_user) do
      render(conn, "show.json", instance: instance)
    end
  end

  @doc """
  Update an instance.
  """
  swagger_path :update do
    put("/contents/{id}")
    summary("Update an instance")
    description("API to update an instance")

    parameters do
      id(:path, :string, "Instance id", required: true)

      content(:body, Schema.ref(:ContentUpdateRequest), "Instance to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Document.get_instance(id, current_user),
         %Instance{} = instance <- Document.update_instance(instance, params) do
      render(conn, "show.json", instance: instance)
    end
  end

  @doc """
  Delete an instance.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/contents/{id}")
    summary("Delete an instance")
    description("API to delete an instance")

    parameters do
      id(:path, :string, "instance id", required: true)
    end

    response(200, "Ok", Schema.ref(:Content))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Document.get_instance(id, current_user),
         _ <- Document.delete_uploaded_docs(current_user, instance),
         {:ok, %Instance{}} <- Document.delete_instance(instance) do
      render(conn, "instance.json", instance: instance)
    end
  end

  @doc """
  Build a document from a content.
  """
  swagger_path :build do
    post("/contents/{id}/build")
    summary("Build a document")
    description("API to build a document from instance")

    parameters do
      id(:path, :string, "instance id", required: true)
      version(:body, Schema.ref(:BuildRequest), "Params for version")
    end

    response(200, "Ok", Schema.ref(:Content))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec build(Plug.Conn.t(), map) :: Plug.Conn.t()
  def build(conn, %{"id" => instance_id} = params) do
    current_user = conn.assigns[:current_user]
    start_time = Timex.now()

    case Document.show_instance(instance_id, current_user) do
      %Instance{content_type: %{layout: layout}} = instance ->
        with %Layout{} = layout <- Document.preload_asset(layout),
             {_, exit_code} <- Document.build_doc(instance, layout) do
          end_time = Timex.now()

          Task.start_link(fn ->
            Document.add_build_history(current_user, instance, %{
              start_time: start_time,
              end_time: end_time,
              exit_code: exit_code
            })
          end)

          handle_response(conn, exit_code, instance, params)
        end

      _ ->
        {:error, :not_sufficient}
    end
  rescue
    DownloadError ->
      conn
      |> put_status(404)
      |> json(%{error: "File not found"})
  end

  defp handle_response(conn, exit_code, instance, params) do
    case exit_code do
      0 ->
        Task.start_link(fn ->
          Document.create_version(conn.assigns.current_user, instance, params)
        end)

        render(conn, "instance.json", instance: instance)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("build_fail.json", %{exit_code: exit_code})
    end
  end

  @doc """
  Update an instance's state.
  """
  swagger_path :state_update do
    patch("/contents/{id}/states")
    summary("Update an instance's state")
    description("API to update an instance's state")

    parameters do
      id(:path, :string, "Instance id", required: true)

      content(:body, Schema.ref(:ContentStateUpdateRequest), "New state of the instance",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec state_update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def state_update(conn, %{"id" => instance_id, "state_id" => state_id}) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Document.get_instance(instance_id, current_user),
         %State{} = state <- Enterprise.get_state(current_user, state_id),
         %Instance{} = instance <- Document.update_instance_state(instance, state) do
      render(conn, "show.json", instance: instance)
    end
  end

  @doc """
  Lock or unlock an instance.
  """
  swagger_path :lock_unlock do
    patch("/contents/{id}/lock-unlock")
    summary("Lock or unlock and instance")
    description("API to update an instanc")

    parameters do
      id(:path, :string, "Instance id", required: true)

      content(:body, Schema.ref(:LockUnlockRequest), "Lock or unlock instance", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec lock_unlock(Plug.Conn.t(), map) :: Plug.Conn.t()
  def lock_unlock(conn, %{"id" => instance_id} = params) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Document.get_instance(instance_id, current_user),
         %Instance{} = instance <-
           Document.lock_unlock_instance(instance, params) do
      render(conn, "show.json", instance: instance)
    end
  end

  @doc """
  Search instances.
  """
  swagger_path :search do
    get("/contents/title/search")
    summary("Search instances")

    description(
      "API to search instances by it title on serialized on instnaces under that organisation"
    )

    parameters do
      key(:query, :string, "Search key")
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:ContentsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def search(conn, %{"key" => key} = params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_index(current_user, key, params) do
      render(conn, "index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  List changes.
  """
  swagger_path :change do
    get("/contents/{id}/change/{v_id}")
    summary("List changes")

    description("API to List changes in a particular version")

    parameters do
      id(:path, :string, "Instance id")
      v_id(:path, :string, "version id")
    end

    response(200, "Ok", Schema.ref(:Change))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec change(Plug.Conn.t(), map) :: Plug.Conn.t()
  def change(conn, %{"id" => instance_id, "v_id" => version_id}) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Document.get_instance(instance_id, current_user) do
      change = Document.version_changes(instance, version_id)

      conn
      |> put_view(InstanceVersionView)
      |> render("change.json", change: change)
    end
  end

  @doc """
  Approve an instance.
  """
  swagger_path :approve do
    put("/contents/{id}/approve")
    summary("Approve an instance")
    description("Api to approve an instance")

    parameters do
      id(:path, :string, "Instance id")
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec approve(Plug.Conn.t(), map) :: Plug.Conn.t()
  def approve(conn, %{"id" => id}) do
    %{current_org_id: organisation_id} = current_user = conn.assigns.current_user

    with %Instance{
           content_type: %ContentType{organisation_id: ^organisation_id},
           state: _state
         } = instance <- Document.show_instance(id, current_user),
         %Instance{} = instance <- Document.approve_instance(current_user, instance) do
      # TODO: add notification
      render(conn, "approve_or_reject.json", %{instance: instance})
    end
  end

  @doc """
  Reject approval of an instance.
  """
  swagger_path :reject do
    put("/contents/{id}/reject")
    summary("Reject approval of an instance")
    description("Api to reject an instance")

    parameters do
      id(:path, :string, "Instance id")
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec reject(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reject(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Document.show_instance(id, current_user),
         %Instance{} = instance <- Document.reject_instance(current_user, instance) do
      render(conn, "approve_or_reject.json", %{instance: instance})
    end
  end

  @doc """
  Send email for an instance.
  """
  swagger_path :send_email do
    post("/contents/{id}/email")
    summary("Document Instance Email")
    description("Api to send email for a given document instance")

    parameters do
      id(:path, :string, "Instance id", required: true)
      content(:body, Schema.ref(:DocumentInstanceMailer), "Mailer Body", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentEmailResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec send_email(Plug.Conn.t(), map) :: Plug.Conn.t()
  def send_email(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Document.show_instance(id, current_user),
         {:ok, _} <- Document.send_document_email(instance, params) do
      render(conn, "email.json", %{info: "Email sent successfully"})
    end
  end

  @doc """
   Share an instance.
  """
  swagger_path :share do
    post("/contents/{id}/share")
    summary("Share an instance")
    description("Api to share an instance")

    parameters do
      id(:path, :string, "Instance id", required: true)
      content(:body, Schema.ref(:ShareDocumentRequest), "Share Request", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec share(Plug.Conn.t(), map) :: Plug.Conn.t()
  def share(conn, %{"id" => document_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{state_id: state_id} = instance <-
           Document.show_instance(document_id, current_user),
         user <- Account.get_user_by_email(params),
         {:ok, %ContentCollaboration{}} <-
           Document.add_content_collaborator(instance, user, params),
         {:ok, %AuthToken{value: token}} <-
           AuthTokens.create_document_invite_token(user, state_id, params),
         %Instance{} = instance <- Document.send_email(instance, user, token) do
      render(conn, "show.json", instance: instance)
    end
  end

  @doc """
  Verify document invite token.
  """
  swagger_path :verify_document_access do
    get("/contents/{id}/verify_access/{token}")
    summary("Verify document invite token")
    description("Api to verify document invite token")

    parameters do
      id(:path, :string, "Instance id", required: true)
      token(:path, :string, "Invite token", required: true)
    end

    response(200, "Ok", Schema.ref(:VerifyDocumentInviteTokenResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec verify_document_access(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_document_access(conn, %{"token" => token, "id" => document_id}) do
    with {:ok, %{email: email, document_id: ^document_id, state_id: state_id}} <-
           AuthTokens.check_token(token, :document_invite),
         user <- Account.get_user_by_email(email),
         %ContentCollaboration{} = content_collaboration <-
           Document.get_content_collaboration(document_id, user, state_id),
         {:ok, %ContentCollaboration{}} <-
           Document.accept_document_access(content_collaboration, user) do
      render(conn, "check_token.json", token: token)
    end
  end

  @doc """
  Revoke document access.
  """
  swagger_path :revoke_document_access do
    PhoenixSwagger.Path.delete("/contents/{id}/revoke_access/{token}")
    summary("Revoke document access")
    description("Api to revoke document access")

    parameters do
      id(:path, :string, "Instance id", required: true)
      token(:path, :string, "Invite token", required: true)
    end

    response(200, "Ok", Schema.ref(:Content))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec revoke_document_access(Plug.Conn.t(), map) :: Plug.Conn.t()
  def revoke_document_access(conn, %{"id" => document_id, "token" => token}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Document.show_instance(document_id, current_user),
         {:ok, %{email: email, document_id: ^document_id, state_id: state_id}} <-
           AuthTokens.check_token(token, :document_invite),
         user <- Account.get_user_by_email(email),
         %ContentCollaboration{} = content_collaboration <-
           Document.get_content_collaboration(document_id, user, state_id),
         {:ok, %ContentCollaboration{}} <-
           Document.revoke_document_access(content_collaboration) do
      render(conn, "show.json", instance: instance)
    end
  end

  @doc """
  List document instance collaborators.
  """
  swagger_path :collaborators do
    get("/contents/{id}/collaborators")
    summary("List document instance collaborators")
    description("Api to list document instance collaborators")

    parameters do
      id(:path, :string, "Instance id", required: true)
    end

    response(200, "Ok", Schema.ref(:Collaborators))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec list_collaborators(Plug.Conn.t(), map) :: Plug.Conn.t()
  def list_collaborators(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Document.show_instance(document_id, current_user),
         %ContentCollaboration{} = content_collaboration <- Document.list_collaborators(instance) do
      render(conn, "collaborators.json", content_collaboration: content_collaboration)
    end
  end

  @doc """
  Update Collaborator role.
  """
  swagger_path :update_collaborator_role do
    put("/contents/{id}/collaborators/{content_collab_id}")
    summary("Update Collaborator role")
    description("Api to update collaborator role")

    parameters do
      id(:path, :string, "Instance id", required: true)
      content_collab_id(:path, :string, "Collaborator id", required: true)
    end

    response(200, "Ok", Schema.ref(:Content))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update_collaborator_role(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_collaborator_role(
        conn,
        %{
          "id" => document_id,
          "content_collab_id" => content_collab_id
        } = params
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Document.show_instance(document_id, current_user),
         %ContentCollaboration{} = content_collaboration <-
           Document.get_content_collaboration(content_collab_id),
         %ContentCollaboration{} = content_collaboration <-
           Document.update_collaborator_role(content_collaboration, params) do
      render(conn, "show_content_collaboration.json",
        content_collaboration: content_collaboration
      )
    end
  end
end
