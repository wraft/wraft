defmodule WraftDocWeb.Api.V1.VendorController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "vendor:manage",
    index: "vendor:show",
    show: "vendor:show",
    update: "vendor:manage",
    delete: "vendor:delete",
    create_contact: "vendor:manage",
    contacts_index: "vendor:show",
    show_contact: "vendor:show",
    update_contact: "vendor:manage",
    delete_contact: "vendor:delete",
    stats: "vendor:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Vendors
  alias WraftDoc.Vendors.Vendor
  alias WraftDoc.Vendors.VendorContact
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Vendor, as: VendorSchema

  tags(["Vendors"])

  operation(:create,
    summary: "Create vendor",
    description: "Create vendor API",
    request_body: {"Vendor to be created", "application/json", VendorSchema.VendorRequest},
    responses: [
      ok: {"Ok", "application/json", VendorSchema.Vendor},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Vendors.create_vendor(current_user, params) do
      render(conn, "create.json", vendor: vendor)
    end
  end

  operation(:index,
    summary: "Vendor index",
    description: "API to get the list of all vendors created so far",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      query: [
        in: :query,
        type: :string,
        description: "Search query to filter vendors by name or email"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", VendorSchema.VendorIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: vendors,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Vendors.vendor_index(current_user, params) do
      render(conn, "index.json",
        vendors: vendors,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a vendor",
    description: "API to show details of a vendor",
    parameters: [
      id: [in: :path, type: :string, description: "vendor id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", VendorSchema.Vendor},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Vendors.show_vendor(id, current_user) do
      render(conn, "create.json", vendor: vendor)
    end
  end

  operation(:update,
    summary: "Update a vendor",
    description: "API to update a vendor",
    parameters: [
      id: [in: :path, type: :string, description: "vendor id", required: true]
    ],
    request_body: {"Vendor to be updated", "application/json", VendorSchema.VendorRequest},
    responses: [
      ok: {"Ok", "application/json", VendorSchema.Vendor},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Vendors.get_vendor(current_user, id),
         %Vendor{} = vendor <- Vendors.update_vendor(vendor, params) do
      render(conn, "vendor.json", vendor: vendor)
    end
  end

  operation(:delete,
    summary: "Delete a vendor",
    description: "API to delete a vendor",
    parameters: [
      id: [in: :path, type: :string, description: "vendor id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", VendorSchema.Vendor},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Vendors.get_vendor(current_user, id),
         {:ok, %Vendor{}} <- Vendors.delete_vendor(vendor) do
      render(conn, "vendor.json", vendor: vendor)
    end
  end

  operation(:create_contact,
    summary: "Create vendor contact",
    description: "Create vendor contact API",
    parameters: [
      vendor_id: [in: :path, type: :string, description: "vendor id", required: true]
    ],
    request_body:
      {"Vendor contact to be created", "application/json", VendorSchema.VendorContactRequest},
    responses: [
      ok: {"Ok", "application/json", VendorSchema.VendorContact},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec create_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_contact(conn, %{"vendor_id" => vendor_id} = params) do
    current_user = conn.assigns.current_user
    params = Map.put(params, "vendor_id", vendor_id)

    with %VendorContact{} = vendor_contact <-
           Vendors.create_vendor_contact(current_user, params) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  operation(:contacts_index,
    summary: "Vendor contacts index",
    description: "API to get the list of all contacts for a vendor",
    parameters: [
      vendor_id: [in: :path, type: :string, description: "vendor id", required: true],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", VendorSchema.VendorContactIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec contacts_index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def contacts_index(conn, %{"vendor_id" => vendor_id} = params) do
    current_user = conn.assigns.current_user

    with %{
           entries: vendor_contacts,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Vendors.vendor_contacts_index(current_user, vendor_id, params) do
      render(conn, "contacts_index.json",
        vendor_contacts: vendor_contacts,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show_contact,
    summary: "Show a vendor contact",
    description: "API to show details of a vendor contact",
    parameters: [
      vendor_id: [in: :path, type: :string, description: "vendor id", required: true],
      id: [in: :path, type: :string, description: "contact id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", VendorSchema.VendorContact},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_contact(conn, %{"vendor_id" => _vendor_id, "id" => id}) do
    current_user = conn.assigns.current_user

    with %VendorContact{} = vendor_contact <- Vendors.get_vendor_contact(current_user, id) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  operation(:update_contact,
    summary: "Update a vendor contact",
    description: "API to update a vendor contact",
    parameters: [
      vendor_id: [in: :path, type: :string, description: "vendor id", required: true],
      id: [in: :path, type: :string, description: "contact id", required: true]
    ],
    request_body:
      {"Vendor contact to be updated", "application/json", VendorSchema.VendorContactRequest},
    responses: [
      ok: {"Ok", "application/json", VendorSchema.VendorContact},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec update_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_contact(conn, %{"vendor_id" => _vendor_id, "id" => id} = params) do
    current_user = conn.assigns.current_user

    with %VendorContact{} = vendor_contact <- Vendors.get_vendor_contact(current_user, id),
         {:ok, %VendorContact{} = vendor_contact} <-
           Vendors.update_vendor_contact(vendor_contact, params) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  operation(:delete_contact,
    summary: "Delete a vendor contact",
    description: "API to delete a vendor contact",
    parameters: [
      vendor_id: [in: :path, type: :string, description: "vendor id", required: true],
      id: [in: :path, type: :string, description: "contact id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", VendorSchema.VendorContact},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_contact(conn, %{"vendor_id" => _vendor_id, "id" => id}) do
    current_user = conn.assigns.current_user

    with %VendorContact{} = vendor_contact <- Vendors.get_vendor_contact(current_user, id),
         {:ok, %VendorContact{}} <- Vendors.delete_vendor_contact(vendor_contact) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  operation(:stats,
    summary: "Get vendor statistics",
    description: "API to get statistics for a specific vendor",
    parameters: [
      vendor_id: [in: :path, type: :string, description: "Vendor ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", VendorSchema.VendorStatsResponse},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stats(conn, %{"vendor_id" => vendor_id}) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Vendors.get_vendor(current_user, vendor_id) do
      stats = Vendors.get_vendor_stats(vendor)
      render(conn, "vendor_stats.json", stats: stats)
    end
  end
end
