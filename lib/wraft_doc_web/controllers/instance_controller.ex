defmodule WraftDocWeb.Api.V1.InstanceController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    index: "document:show",
    all_contents: "document:show",
    show: "document:show",
    update: "document:manage",
    delete: "document:delete",
    build: "document:manage",
    state_update: "document:manage",
    lock_unlock: "document:lock",
    search: "document:show",
    change: "document:show",
    approve: "document:review",
    reject: "document:review",
    get_logs: "document:show"

  plug WraftDocWeb.Plug.AddDocumentAuditLog
       when action in [:create, :update, :approve, :build, :invite]

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  alias WraftDoc.Assets
  alias WraftDoc.Client.Minio.DownloadError
  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Charts
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Instance.Version
  alias WraftDoc.Documents.Reminders
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Frames
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDoc.Webhooks.EventTrigger
  alias WraftDocWeb.Api.V1.InstanceVersionView
  alias WraftDocWeb.Schemas.Content, as: ContentSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Instance"])

  operation(:create,
    summary: "Create a content",
    description: "Create content API",
    parameters: [
      c_type_id: [in: :path, type: :string, description: "content type id", required: true]
    ],
    request_body: {"Content to be created", "application/json", ContentSchema.ContentRequest},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ContentAndContentTypeAndState},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(
        conn,
        %{"c_type_id" => c_type_id} = params
      ) do
    current_user = conn.assigns[:current_user]
    type = Instance.types()[:normal]

    params =
      Map.merge(params, %{
        "type" => type,
        "doc_settings" => params["doc_settings"] || %{}
      })

    with %ContentType{} = c_type <- ContentTypes.show_content_type(current_user, c_type_id),
         %Instance{id: content_id} = content <-
           Documents.create_instance(current_user, c_type, params) do
      Typesense.create_document(content)
      Task.start(fn -> EventTrigger.trigger_document_created(content) end)

      conn
      |> Map.update!(:params, &Map.put(&1, "id", content_id))
      |> render(:create, content: content)
    else
      error ->
        error
    end
  end

  operation(:index,
    summary: "Instance index",
    description: "API to get the list of all instances created so far under a content type",
    parameters: [
      c_type_id: [in: :path, type: :string, description: "ID of the content type", required: true],
      page: [in: :query, type: :string, description: "Page number"],
      instance_id: [in: :query, type: :string, description: "Instance ID"],
      creator_id: [in: :query, type: :string, description: "Creator ID"],
      sort: [
        in: :query,
        type: :string,
        description: "sort keys => instance_id, instance_id_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ContentsIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"c_type_id" => c_type_id} = params) do
    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.instance_index(c_type_id, params) do
      render(conn, "index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:list_pending_approvals,
    summary: "List pending approvals",
    description: "API to get the list of pending approvals for current user",
    responses: [
      ok: {"Ok", "application/json", ContentSchema.InstanceApprovals},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def list_pending_approvals(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.list_pending_approvals(current_user, params) do
      render(conn, "approvals_index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:all_contents,
    summary: "All instances",
    description: "API to get the list of all instances created so far under an organisation",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      instance_id: [in: :query, type: :string, description: "Instance ID"],
      content_type_name: [in: :query, type: :string, description: "Content Type name"],
      creator_id: [in: :query, type: :string, description: "Creator ID"],
      state: [in: :query, type: :string, description: "State, eg: published, draft, review"],
      document_instance_title: [in: :query, type: :string, description: "Document instance title"],
      status: [in: :query, type: :string, description: "Status, eg: expired, upcoming"],
      type: [in: :query, type: :string, description: "Type, eg: contract, document"],
      sort: [
        in: :query,
        type: :string,
        description:
          "sort keys => instance_id, instance_id_desc, inserted_at, inserted_at_desc, expiry_date, expiry_date_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ContentsIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec all_contents(Plug.Conn.t(), map) :: Plug.Conn.t()
  def all_contents(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.instance_index_of_an_organisation(current_user, params) do
      render(conn, "instance_summaries_paginated.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show an instance",
    description: "API to get all details of an instance",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the instance", required: true],
      version_type: [in: :query, type: :string, description: "Version type", required: false]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # Guest user
  def show(conn, %{"id" => document_id, "auth_type" => "guest"}) do
    current_user = conn.assigns.current_user

    with true <- Documents.has_access?(current_user, document_id),
         %Instance{} = instance <- Documents.show_instance(document_id, current_user) do
      render(conn, "show.json", instance: instance)
    end
  end

  def show(conn, %{"id" => instance_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(instance_id, current_user) do
      render(conn, "show.json", instance: instance)
    end
  end

  operation(:update,
    summary: "Update an instance",
    description: "API to update an instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    request_body:
      {"Instance to be updated", "application/json", ContentSchema.ContentUpdateRequest},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  # Guest user
  def update(conn, %{"id" => document_id, "type" => "guest"} = params) do
    current_user = conn.assigns.current_user

    with true <- Documents.has_access?(current_user, document_id, :editor),
         %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %Instance{} = instance <- Documents.update_instance(instance, params),
         {:ok, _version} <- Documents.create_version(current_user, instance, params, :save) do
      render(conn, "show.json", instance: instance)
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Documents.get_instance(id, current_user),
         %Instance{} = instance <- Documents.update_instance(instance, params),
         {:ok, _version} <- Documents.create_version(current_user, instance, params, :save) do
      Typesense.update_document(instance)
      render(conn, "show.json", instance: instance)
    end
  end

  operation(:update_meta,
    summary: "Update meta data of an instance",
    description: "API to update meta data of an instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    request_body:
      {"Meta data to be updated", "application/json", ContentSchema.MetaUpdateRequest},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update_meta(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_meta(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Documents.get_instance(id, current_user),
         {:ok, %Instance{meta: meta}} <- Documents.update_meta(instance, params) do
      render(conn, "meta.json", meta: meta)
    end
  end

  operation(:delete,
    summary: "Delete an instance",
    description: "API to delete an instance",
    parameters: [
      id: [in: :path, type: :string, description: "instance id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.Content},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Documents.get_instance(id, current_user),
         _ <- Documents.delete_uploaded_docs(current_user, instance),
         {:ok, %Instance{id: instance_id} = instance} <- Documents.delete_instance(instance) do
      Typesense.delete_document(instance_id, "content")

      # Trigger webhook for document deletion
      Task.start(fn ->
        EventTrigger.trigger_document_deleted(instance)
      end)

      render(conn, "instance.json", instance: instance)
    end
  end

  operation(:build,
    summary: "Build a document",
    description: "API to build a document from instance",
    parameters: [
      id: [in: :path, type: :string, description: "instance id", required: true]
    ],
    request_body: {"Params for version", "application/json", ContentSchema.BuildRequest},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.Content},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec build(Plug.Conn.t(), map) :: Plug.Conn.t()
  def build(conn, %{"id" => instance_id} = params) do
    current_user = conn.assigns[:current_user]
    start_time = Timex.now()

    case Documents.show_instance(instance_id, current_user) do
      %Instance{content_type: %{layout: layout} = content_type} = instance ->
        with %Layout{} = layout <- Assets.preload_asset(layout),
             :ok <- Frames.check_frame_mapping(content_type),
             {_error, exit_code} = build_response <- Documents.build_doc(instance, layout) do
          end_time = Timex.now()

          Task.start_link(fn ->
            Documents.add_build_history(current_user, instance, %{
              start_time: start_time,
              end_time: end_time,
              exit_code: exit_code
            })
          end)

          handle_response(conn, build_response, instance, params)
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

  defp handle_response(conn, build_response, instance, params) do
    case build_response do
      {_, 0} ->
        Task.start_link(fn ->
          Documents.create_version(conn.assigns.current_user, instance, params, :build)
        end)

        render(conn, "instance.json", instance: instance)

      {error, exit_code} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("build_fail.json", %{exit_code: exit_code, error: error})
    end
  end

  operation(:state_update,
    summary: "Update an instance's state",
    description: "API to update an instance's state",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    request_body:
      {"New state of the instance", "application/json", ContentSchema.ContentStateUpdateRequest},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec state_update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def state_update(conn, %{"id" => instance_id, "state_id" => state_id}) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Documents.get_instance(instance_id, current_user),
         %Instance{state: previous_state} = instance_with_state <- Repo.preload(instance, :state),
         %State{} = state <- Enterprise.get_state(current_user, state_id),
         %Instance{} = updated_instance <-
           Documents.update_instance_state(instance_with_state, state) do
      # Trigger webhook for state update
      Task.start(fn ->
        previous_state_info = %{
          id: previous_state.id,
          state: previous_state.state,
          order: previous_state.order
        }

        EventTrigger.trigger_document_state_updated(updated_instance, previous_state_info)
      end)

      render(conn, "show.json", instance: updated_instance)
    end
  end

  operation(:lock_unlock,
    summary: "Lock or unlock and instance",
    description: "API to update an instanc",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    request_body:
      {"Lock or unlock instance", "application/json", ContentSchema.LockUnlockRequest},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec lock_unlock(Plug.Conn.t(), map) :: Plug.Conn.t()
  def lock_unlock(conn, %{"id" => instance_id} = params) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Documents.get_instance(instance_id, current_user),
         %Instance{} = instance <-
           Documents.lock_unlock_instance(instance, params) do
      render(conn, "show.json", instance: instance)
    end
  end

  operation(:search,
    summary: "Search instances",
    description:
      "API to search instances by it title on serialized on instnaces under that organisation",
    parameters: [
      key: [in: :query, type: :string, description: "Search key"],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ContentsIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def search(conn, %{"key" => key} = params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.instance_index(current_user, key, params) do
      render(conn, "instance_summaries_paginated.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:change,
    summary: "List changes",
    description: "API to List changes in a particular version",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id"],
      v_id: [in: :path, type: :string, description: "version id"]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.Change},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec change(Plug.Conn.t(), map) :: Plug.Conn.t()
  def change(conn, %{"id" => instance_id, "v_id" => version_id}) do
    current_user = conn.assigns[:current_user]

    with %Instance{} = instance <- Documents.get_instance(instance_id, current_user) do
      change = Documents.version_changes(instance, version_id)

      conn
      |> put_view(InstanceVersionView)
      |> render("change.json", change: change)
    end
  end

  operation(:approve,
    summary: "Approve an instance",
    description: "Api to approve an instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id"]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec approve(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def approve(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Instance{
           content_type: %ContentType{
             organisation: %Organisation{} = organisation
           },
           state: state
         } = instance <- Documents.show_instance(id, current_user),
         {:ok, %Instance{} = approved_instance, audit_message} <-
           Documents.approve_instance(current_user, instance) do
      Task.start(fn -> Reminders.maybe_create_auto_reminders(current_user, approved_instance) end)

      Task.start(fn ->
        Documents.document_notification(
          current_user,
          approved_instance,
          organisation,
          state
        )
      end)

      # Trigger webhook for document completion if the document workflow is completed
      Task.start(fn ->
        EventTrigger.trigger_document_state_updated(instance, %{
          id: approved_instance.state.id,
          state: approved_instance.state.state,
          order: approved_instance.state.order
        })

        if approved_instance.state && approved_instance.state.state == "completed" do
          EventTrigger.trigger_document_completed(approved_instance)
        end
      end)

      conn
      |> Plug.Conn.assign(:audit_log_message, audit_message)
      |> render("approve_or_reject.json", %{instance: instance})
    end
  end

  operation(:reject,
    summary: "Reject approval of an instance",
    description: "Api to reject an instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id"]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ShowContent},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec reject(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reject(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(id, current_user),
         %Instance{} = rejected_instance <- Documents.reject_instance(current_user, instance) do
      # Trigger webhook for document rejection
      Task.start(fn ->
        EventTrigger.trigger_document_rejected(rejected_instance)
      end)

      render(conn, "approve_or_reject.json", %{instance: rejected_instance})
    end
  end

  operation(:send_email,
    summary: "Document Instance Email",
    description: "Api to send email for a given document instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    request_body: {"Mailer Body", "application/json", ContentSchema.DocumentInstanceMailer},
    responses: [
      ok: {"Ok", "application/json", ContentSchema.ContentEmailResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec send_email(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def send_email(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(id, current_user),
         {:ok, _} <- Documents.send_document_email(instance, params) do
      Task.start(fn -> EventTrigger.trigger_document_sent(instance) end)
      render(conn, "email.json", %{info: "Email sent successfully"})
    end
  end

  operation(:contract_chart,
    summary: "Get contract chart analytics",
    description: """
    Retrieve contract analytics data grouped by time intervals with flexible period filtering.

    ## Business Logic:
    - **total**: Total count of contracts in the time interval
    - **confirmed**: Contracts with approval_status: true in meta field
    - **pending**: total - confirmed (remaining contracts that aren't confirmed)

    ## Period-Interval Validation Rules:
    - **today** → interval must be: "hour" or "day"
    - **7days** → interval can be: "hour" or "day"
    - **month** → interval can be: "day" or "week"
    - **year** → interval can be: "day", "week", or "month"
    - **alltime** → interval can be: "week", "month", or "year"
    - **custom** → interval can be: "hour", "day", "week", "month", or "year"

    ## Custom Period Additional Validation:
    - **Hour interval**: Not recommended for date ranges > 31 days
    - **Day interval**: Not recommended for date ranges > 365 days
    - **Week interval**: Requires at least 7 days between from and to dates
    - **Month interval**: Requires at least 31 days between from and to dates
    """,
    parameters: [
      period: [
        in: :query,
        type: :string,
        description:
          "Time period for filtering contracts (today, 7days, month, year, alltime, custom; default: month)"
      ],
      interval: [
        in: :query,
        type: :string,
        description:
          "Time interval for grouping results (hour, day, week, month, year; default: week)"
      ],
      doc_type: [
        in: :query,
        type: :string,
        description:
          "Field to filter contents by their type (contract, document, both; default: both)"
      ],
      select_by: [
        in: :query,
        type: :string,
        description: "Field to filter contracts by (insert, update; default: insert)"
      ],
      from: [
        in: :query,
        type: :string,
        description:
          "Start datetime for custom period (ISO8601 format, e.g., 2024-04-01T00:00:00Z)"
      ],
      to: [
        in: :query,
        type: :string,
        description: "End datetime for custom period (ISO8601 format, e.g., 2024-04-30T23:59:59Z)"
      ]
    ],
    responses: [
      ok:
        {"Contract chart data retrieved successfully", "application/json",
         ContentSchema.ContractChart},
      bad_request:
        {"Bad Request - Invalid parameters or period-interval combination", "application/json",
         Error},
      unauthorized: {"Unauthorized - Authentication required", "application/json", Error},
      unprocessable_entity:
        {"Unprocessable Entity - Validation errors", "application/json", Error},
      internal_server_error: {"Internal Server Error", "application/json", Error}
    ]
  )

  def contract_chart(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, contract_list} <- Charts.get_contract_chart(current_user, params) do
      render(conn, "contract_chart.json", contract_list: contract_list)
    end
  end

  operation(:restore,
    summary: "Restore a specific version of an instance",
    description: "Restores a content instance to a previous version",
    parameters: [
      id: [in: :path, type: :string, description: "Instance ID", required: true],
      version_id: [in: :path, type: :string, description: "Version ID to restore", required: true]
    ],
    responses: [
      ok:
        {"Instance version restored successfully", "application/json",
         ContentSchema.RestoreContent},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Instance or version not found", "application/json", Error}
    ]
  )

  @spec restore(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def restore(conn, %{"id" => id, "version_id" => version_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(id, current_user),
         %Instance{} = instance <- Documents.restore_version(instance, version_id) do
      render(conn, "restore.json", content: instance)
    end
  end

  operation(:update_version,
    summary: "Update a specific version",
    description: "Updates metadata or content of a specific version",
    parameters: [
      id: [in: :path, type: :string, description: "Version ID", required: true]
    ],
    request_body:
      {"Narration for the version", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{naration: %OpenApiSpex.Schema{type: :string}}
       }},
    responses: [
      ok: {"Version updated successfully", "application/json", ContentSchema.VersionResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Version not found", "application/json", Error},
      unprocessable_entity:
        {"Unprocessable Entity - Validation errors", "application/json", Error}
    ]
  )

  @spec update_version(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_version(conn, %{"id" => version_id} = params) do
    with %Version{} = version <- Documents.update_version(version_id, params) do
      conn
      |> put_view(WraftDocWeb.Api.V1.InstanceVersionView)
      |> render("version.json", version: version)
    end
  end

  operation(:index_versions,
    summary: "List all versions",
    description: "Lists all versions of an instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance ID", required: true],
      type: [in: :query, type: :string, description: "Type of versions to list"],
      page: [in: :query, type: :string, description: "Page number"],
      sort: [
        in: :query,
        type: :string,
        description: "sort keys => updated_at, updated_at_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok:
        {"Versions listed successfully", "application/json",
         ContentSchema.PaginatedVersionResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Instance not found", "application/json", Error}
    ]
  )

  @spec index_versions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index_versions(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(id, current_user),
         %{
           entries: versions,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.list_versions(instance, params) do
      conn
      |> put_view(WraftDocWeb.Api.V1.InstanceVersionView)
      |> render("versions.json",
        versions: versions,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:compare_versions,
    summary: "Compare two document versions",
    description: "Compares two document versions to see the differences between them",
    parameters: [
      id1: [in: :path, type: :string, description: "First version ID to compare", required: true],
      id2: [in: :path, type: :string, description: "Second version ID to compare", required: true]
    ],
    responses: [
      ok:
        {"Comparison performed successfully", "application/json", ContentSchema.VersionComparison},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"One or both versions not found", "application/json", Error},
      unprocessable_entity:
        {"Unprocessable Entity - Versions cannot be compared", "application/json", Error}
    ]
  )

  @spec compare_versions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def compare_versions(conn, %{"id1" => id1, "id2" => id2}) do
    with {:ok, comparison} <- Documents.compare_versions(id1, id2) do
      conn
      |> put_view(WraftDocWeb.Api.V1.InstanceVersionView)
      |> render("comparison.json", comparison: comparison)
    end
  end

  @doc """
  Get logs for an instance.
  """
  operation(:get_logs,
    summary: "Get instance logs",
    description: "Retrieve logs of actions performed on a specific instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", ContentSchema.Logs},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def get_logs(conn, %{"id" => instance_id} = params) do
    current_user = conn.assigns.current_user

    with %{
           entries: entries,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <-
           Documents.get_logs(current_user, instance_id, params) do
      render(conn, "logs.json", %{
        entries: entries,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      })
    end
  end
end
