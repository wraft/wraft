defmodule WraftDocWeb.Api.V1.VendorController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Organisation.VendorContact

  def swagger_definitions do
    %{
      VendorRequest:
        swagger_schema do
          title("Vendor Request")
          description("Create vendor request.")

          properties do
            name(:string, "Vendors name", required: true)
            email(:string, "Vendors email")
            phone(:string, "Phone number")
            address(:string, "The Address of the vendor")
            city(:string, "The City of the vendor")
            country(:string, "The Country of the vendor")
            website(:string, "The Website of the vendor")
            gstin(:string, "The Gstin of the vendor")
            reg_no(:string, "The RegNo of the vendor")
            contact_person(:string, "The ContactPerson of the vendor")
          end

          example(%{
            name: "Vos Services",
            email: "serv@vosmail.com",
            phone: "98565262262",
            address: "rose boru, hourbures",
            city: "Mumbai",
            country: "India",
            website: "https://vosservices.com",
            gstin: "32ADF22SDD2DFS32SDF",
            reg_no: "ASD21122",
            contact_person: "vikas abu"
          })
        end,
      Vendor:
        swagger_schema do
          title("Vendor")
          description("A Vendor")

          properties do
            id(:string, "Vendor ID")
            name(:string, "Vendors name")
            email(:string, "Vendors email")
            phone(:string, "Phone number")
            address(:string, "The Address of the vendor")
            city(:string, "The City of the vendor")
            country(:string, "The Country of the vendor")
            website(:string, "The Website of the vendor")
            gstin(:string, "The Gstin of the vendor")
            reg_no(:string, "The RegNo of the vendor")
            contact_person(:string, "The ContactPerson of the vendor")
            inserted_at(:string, "When was the vendor inserted", format: "ISO-8601")
            updated_at(:string, "When was the vendor last updated", format: "ISO-8601")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "Vos Services",
            email: "serv@vosmail.com",
            phone: "98565262262",
            address: "rose boru, hourbures",
            city: "Mumbai",
            country: "India",
            website: "https://vosservices.com",
            gstin: "32ADF22SDD2DFS32SDF",
            reg_no: "ASD21122",
            contact_person: "vikas abu",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      Vendors:
        swagger_schema do
          title("Vendor list")
          type(:array)
          items(Schema.ref(:Vendor))
        end,
      VendorIndex:
        swagger_schema do
          properties do
            vendors(Schema.ref(:Vendors))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            vendors: [
              %{
                id: "123e4567-e89b-12d3-a456-426614174000",
                name: "Vos Services",
                email: "serv@vosmail.com",
                phone: "98565262262",
                address: "rose boru, hourbures",
                city: "Mumbai",
                country: "India",
                website: "https://vosservices.com",
                gstin: "32ADF22SDD2DFS32SDF",
                reg_no: "ASD21122",
                contact_person: "vikas abu",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end,
      VendorContactRequest:
        swagger_schema do
          title("Vendor Contact Request")
          description("Create vendor contact request.")

          properties do
            name(:string, "Contact person name", required: true)
            email(:string, "Contact person email")
            phone(:string, "Contact person phone")
            job_title(:string, "Contact person job title")
            vendor_id(:string, "Vendor ID", required: true)
          end

          example(%{
            name: "John Doe",
            email: "john.doe@vosservices.com",
            phone: "9876543210",
            job_title: "Sales Manager",
            vendor_id: "123e4567-e89b-12d3-a456-426614174000"
          })
        end,
      VendorContact:
        swagger_schema do
          title("Vendor Contact")
          description("A Vendor Contact")

          properties do
            id(:string, "Contact ID")
            name(:string, "Contact person name")
            email(:string, "Contact person email")
            phone(:string, "Contact person phone")
            job_title(:string, "Contact person job title")
            vendor_id(:string, "Vendor ID")
            inserted_at(:string, "When was the contact inserted", format: "ISO-8601")
            updated_at(:string, "When was the contact last updated", format: "ISO-8601")
          end

          example(%{
            id: "456e7890-e12b-34c5-d678-901234567890",
            name: "John Doe",
            email: "john.doe@vosservices.com",
            phone: "9876543210",
            job_title: "Sales Manager",
            vendor_id: "123e4567-e89b-12d3-a456-426614174000",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      VendorContacts:
        swagger_schema do
          title("Vendor Contact list")
          type(:array)
          items(Schema.ref(:VendorContact))
        end,
      VendorContactIndex:
        swagger_schema do
          properties do
            vendor_contacts(Schema.ref(:VendorContacts))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contacts")
          end

          example(%{
            vendor_contacts: [
              %{
                id: "456e7890-e12b-34c5-d678-901234567890",
                name: "John Doe",
                email: "john.doe@vosservices.com",
                phone: "9876543210",
                job_title: "Sales Manager",
                vendor_id: "123e4567-e89b-12d3-a456-426614174000",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 1,
            total_entries: 5
          })
        end
    }
  end

  swagger_path :create do
    post("/vendors")
    summary("Create vendor")
    description("Create vendor API")

    parameters do
      vendor(:body, Schema.ref(:VendorRequest), "Vendor to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Vendor))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Enterprise.create_vendor(current_user, params) do
      render(conn, "create.json", vendor: vendor)
    end
  end

  swagger_path :index do
    get("/vendors")
    summary("Vendor index")
    description("API to get the list of all vendors created so far")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:VendorIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: vendors,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.vendor_index(current_user, params) do
      render(conn, "index.json",
        vendors: vendors,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :show do
    get("/vendors/{id}")
    summary("Show a vendor")
    description("API to show details of a vendor")

    parameters do
      id(:path, :string, "vendor id", required: true)
    end

    response(200, "Ok", Schema.ref(:Vendor))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Enterprise.show_vendor(id, current_user) do
      render(conn, "create.json", vendor: vendor)
    end
  end

  swagger_path :update do
    put("/vendors/{id}")
    summary("Update a vendor")
    description("API to update a vendor")

    parameters do
      id(:path, :string, "vendor id", required: true)
      vendor(:body, Schema.ref(:VendorRequest), "Vendor to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Vendor))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Enterprise.get_vendor(current_user, id),
         %Vendor{} = vendor <- Enterprise.update_vendor(vendor, params) do
      render(conn, "vendor.json", vendor: vendor)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/vendors/{id}")
    summary("Delete a vendor")
    description("API to delete a vendor")

    parameters do
      id(:path, :string, "vendor id", required: true)
    end

    response(200, "Ok", Schema.ref(:Vendor))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Vendor{} = vendor <- Enterprise.get_vendor(current_user, id),
         {:ok, %Vendor{}} <- Enterprise.delete_vendor(vendor) do
      render(conn, "vendor.json", vendor: vendor)
    end
  end

  # ===============================
  # VENDOR CONTACT CRUD OPERATIONS
  # ===============================

  swagger_path :create_contact do
    post("/vendors/{vendor_id}/contacts")
    summary("Create vendor contact")
    description("Create vendor contact API")

    parameters do
      vendor_id(:path, :string, "vendor id", required: true)

      vendor_contact(:body, Schema.ref(:VendorContactRequest), "Vendor contact to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:VendorContact))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_contact(conn, %{"vendor_id" => vendor_id} = params) do
    current_user = conn.assigns.current_user
    params = Map.put(params, "vendor_id", vendor_id)

    with %VendorContact{} = vendor_contact <-
           Enterprise.create_vendor_contact(current_user, params) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  swagger_path :contacts_index do
    get("/vendors/{vendor_id}/contacts")
    summary("Vendor contacts index")
    description("API to get the list of all contacts for a vendor")

    parameters do
      vendor_id(:path, :string, "vendor id", required: true)
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:VendorContactIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec contacts_index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def contacts_index(conn, %{"vendor_id" => vendor_id} = params) do
    current_user = conn.assigns.current_user

    with %{
           entries: vendor_contacts,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.vendor_contacts_index(current_user, vendor_id, params) do
      render(conn, "contacts_index.json",
        vendor_contacts: vendor_contacts,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :show_contact do
    get("/vendors/{vendor_id}/contacts/{id}")
    summary("Show a vendor contact")
    description("API to show details of a vendor contact")

    parameters do
      vendor_id(:path, :string, "vendor id", required: true)
      id(:path, :string, "contact id", required: true)
    end

    response(200, "Ok", Schema.ref(:VendorContact))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_contact(conn, %{"vendor_id" => _vendor_id, "id" => id}) do
    current_user = conn.assigns.current_user

    with %VendorContact{} = vendor_contact <- Enterprise.get_vendor_contact(current_user, id) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  swagger_path :update_contact do
    put("/vendors/{vendor_id}/contacts/{id}")
    summary("Update a vendor contact")
    description("API to update a vendor contact")

    parameters do
      vendor_id(:path, :string, "vendor id", required: true)
      id(:path, :string, "contact id", required: true)

      vendor_contact(:body, Schema.ref(:VendorContactRequest), "Vendor contact to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:VendorContact))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_contact(conn, %{"vendor_id" => _vendor_id, "id" => id} = params) do
    current_user = conn.assigns.current_user

    with %VendorContact{} = vendor_contact <- Enterprise.get_vendor_contact(current_user, id),
         {:ok, %VendorContact{} = vendor_contact} <-
           Enterprise.update_vendor_contact(vendor_contact, params) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end

  swagger_path :delete_contact do
    PhoenixSwagger.Path.delete("/vendors/{vendor_id}/contacts/{id}")
    summary("Delete a vendor contact")
    description("API to delete a vendor contact")

    parameters do
      vendor_id(:path, :string, "vendor id", required: true)
      id(:path, :string, "contact id", required: true)
    end

    response(200, "Ok", Schema.ref(:VendorContact))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete_contact(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_contact(conn, %{"vendor_id" => _vendor_id, "id" => id}) do
    current_user = conn.assigns.current_user

    with %VendorContact{} = vendor_contact <- Enterprise.get_vendor_contact(current_user, id),
         {:ok, %VendorContact{}} <- Enterprise.delete_vendor_contact(vendor_contact) do
      render(conn, "vendor_contact.json", vendor_contact: vendor_contact)
    end
  end
end
