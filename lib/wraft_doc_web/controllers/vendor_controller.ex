defmodule WraftDocWeb.Api.V1.VendorController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Enterprise, Enterprise.Vendor}

  def swagger_definitions do
    %{
      VendorRequest:
        swagger_schema do
          title("Vendor Request")
          description("Create vendor request.")

          properties do
            name(:string, "Vendors name", required: true)
            email(:string, "Vendors email", required: true)
            phone(:string, "Phone number", required: true)
            address(:string, "The Address of the vendor", required: true)
            gstin(:string, "The Gstin of the vendor", required: true)
            reg_no(:string, "The RegNo of the vendor", required: true)

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

            inserted_at(:string, "When was the vendor inserted", format: "ISO-8601")
            updated_at(:string, "When was the vendor last updated", format: "ISO-8601")
          end

          example(%{
            name: "Vos Services",
            email: "serv@vosmail.com",
            phone: "98565262262",
            address: "rose boru, hourbures",
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
                name: "Vos Services",
                email: "serv@vosmail.com",
                phone: "98565262262",
                address: "rose boru, hourbures",
                gstin: "32ADF22SDD2DFS32SDF",
                reg_no: "ASD21122",
                contact_person: "vikas abu",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              },
              %{
                name: "Vos Services",
                email: "serv@vosmail.com",
                phone: "98565262262",
                address: "rose boru, hourbures",
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
end
