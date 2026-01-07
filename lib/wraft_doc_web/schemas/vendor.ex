defmodule WraftDocWeb.Schemas.Vendor do
  @moduledoc """
  Schema for Vendor request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule VendorRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Request",
      description: "Create vendor request.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Vendors name"},
        email: %Schema{type: :string, description: "Vendors email"},
        phone: %Schema{type: :string, description: "Phone number"},
        address: %Schema{type: :string, description: "The Address of the vendor"},
        city: %Schema{type: :string, description: "The City of the vendor"},
        country: %Schema{type: :string, description: "The Country of the vendor"},
        website: %Schema{type: :string, description: "The Website of the vendor"},
        gstin: %Schema{type: :string, description: "The Gstin of the vendor"},
        reg_no: %Schema{type: :string, description: "The RegNo of the vendor"},
        contact_person: %Schema{type: :string, description: "The ContactPerson of the vendor"}
      },
      required: [:name],
      example: %{
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
      }
    })
  end

  defmodule Vendor do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor",
      description: "A Vendor",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Vendor ID"},
        name: %Schema{type: :string, description: "Vendors name"},
        email: %Schema{type: :string, description: "Vendors email"},
        phone: %Schema{type: :string, description: "Phone number"},
        address: %Schema{type: :string, description: "The Address of the vendor"},
        city: %Schema{type: :string, description: "The City of the vendor"},
        country: %Schema{type: :string, description: "The Country of the vendor"},
        website: %Schema{type: :string, description: "The Website of the vendor"},
        gstin: %Schema{type: :string, description: "The Gstin of the vendor"},
        reg_no: %Schema{type: :string, description: "The RegNo of the vendor"},
        contact_person: %Schema{type: :string, description: "The ContactPerson of the vendor"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the vendor inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the vendor last updated",
          format: "ISO-8601"
        }
      },
      example: %{
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
    })
  end

  defmodule Vendors do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor list",
      type: :array,
      items: Vendor
    })
  end

  defmodule VendorIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Index",
      type: :object,
      properties: %{
        vendors: Vendors,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
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
      }
    })
  end

  defmodule VendorContactRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Contact Request",
      description: "Create vendor contact request.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Contact person name"},
        email: %Schema{type: :string, description: "Contact person email"},
        phone: %Schema{type: :string, description: "Contact person phone"},
        job_title: %Schema{type: :string, description: "Contact person job title"},
        vendor_id: %Schema{type: :string, description: "Vendor ID"}
      },
      required: [:name, :vendor_id],
      example: %{
        name: "John Doe",
        email: "john.doe@vosservices.com",
        phone: "9876543210",
        job_title: "Sales Manager",
        vendor_id: "123e4567-e89b-12d3-a456-426614174000"
      }
    })
  end

  defmodule VendorContact do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Contact",
      description: "A Vendor Contact",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Contact ID"},
        name: %Schema{type: :string, description: "Contact person name"},
        email: %Schema{type: :string, description: "Contact person email"},
        phone: %Schema{type: :string, description: "Contact person phone"},
        job_title: %Schema{type: :string, description: "Contact person job title"},
        vendor_id: %Schema{type: :string, description: "Vendor ID"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the contact inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the contact last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "456e7890-e12b-34c5-d678-901234567890",
        name: "John Doe",
        email: "john.doe@vosservices.com",
        phone: "9876543210",
        job_title: "Sales Manager",
        vendor_id: "123e4567-e89b-12d3-a456-426614174000",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule VendorContacts do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Contact list",
      type: :array,
      items: VendorContact
    })
  end

  defmodule VendorContactIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Contact Index",
      type: :object,
      properties: %{
        vendor_contacts: VendorContacts,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contacts"}
      },
      example: %{
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
      }
    })
  end

  defmodule VendorStatsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Vendor Statistics Response",
      description: "Statistics for a specific vendor",
      type: :object,
      properties: %{
        total_documents: %Schema{
          type: :integer,
          description: "Total number of documents connected to this vendor"
        },
        pending_approvals: %Schema{
          type: :integer,
          description: "Number of documents awaiting approval"
        },
        total_contract_value: %Schema{
          type: :string,
          description: "Combined value of all contracts"
        },
        total_contacts: %Schema{
          type: :integer,
          description: "Number of vendor contacts registered"
        },
        new_this_month: %Schema{
          type: :integer,
          description: "Number of vendors added this month in the organization"
        }
      },
      example: %{
        total_documents: 847,
        pending_approvals: 34,
        total_contract_value: "2500000.00",
        total_contacts: 293,
        new_this_month: 18
      }
    })
  end
end
