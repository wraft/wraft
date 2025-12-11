defmodule WraftDocWeb.Schemas.Content do
  @moduledoc """
  Schema for Content request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Content do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content",
      description: "A content, which is then used to generate the out files.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content"},
        instance_id: %Schema{type: :string, description: "A unique ID generated for the content"},
        raw: %Schema{type: :string, description: "Raw data of the content"},
        serialized: %Schema{type: :object, description: "Serialized data of the content"},
        build: %Schema{type: :string, description: "URL of the build document"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the engine inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the engine last updated",
          format: "ISO-8601"
        }
      },
      required: [:id],
      example: %{
        id: "1232148nb3478",
        instance_id: "OFFL01",
        raw: "Content",
        serialized: %{title: "Title of the content", body: "Body of the content"},
        build: "/uploads/OFFL01/OFFL01-v1.pdf",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule InstanceApprovals do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "InstanceApprovals",
      description: "Get list of pending approvals for current user",
      type: :object,
      example: %{
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
      }
    })
  end

  defmodule ContentRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Request",
      description: "Content creation request",
      type: :object,
      properties: %{
        raw: %Schema{type: :string, description: "Content raw data"},
        serialized: %Schema{type: :string, description: "Content serialized data"},
        vendor_id: %Schema{
          type: :string,
          description: "Vendor ID to associate with this document"
        }
      },
      required: [:raw],
      example: %{
        raw: "Content data",
        serialized: %{title: "Title of the content", body: "Body of the content"},
        vendor_id: "123e4567-e89b-12d3-a456-426614174000"
      }
    })
  end

  defmodule ContentUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content update Request",
      description: "Content updation request",
      type: :object,
      properties: %{
        raw: %Schema{type: :string, description: "Content raw data"},
        serialized: %Schema{type: :string, description: "Content serialized data"},
        naration: %Schema{type: :string, description: "Naration for updation"},
        vendor_id: %Schema{
          type: :string,
          description: "Vendor ID to associate with this document"
        }
      },
      required: [:raw],
      example: %{
        raw: "Content data",
        serialized: %{title: "Title of the content", body: "Body of the content"},
        naration: "Revision by manager",
        vendor_id: "123e4567-e89b-12d3-a456-426614174000"
      }
    })
  end

  defmodule ContentStateUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content state update Request",
      description: "Content state update request",
      type: :object,
      properties: %{
        state_id: %Schema{type: :string, description: "state id"}
      },
      required: [:state_id],
      example: %{
        state_id: "kjb12389k23eyg"
      }
    })
  end

  defmodule ContentAndContentTypeAndState do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content and its Content Type",
      description: "A content and its content type",
      type: :object,
      properties: %{
        content: %Schema{anyOf: [Content]},
        content_type: %Schema{anyOf: [WraftDocWeb.Schemas.ContentType.ContentTypeWithoutFields]},
        state: %Schema{anyOf: [WraftDocWeb.Schemas.State.State]}
      },
      example: %{
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
      }
    })
  end

  defmodule ShowContent do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content and its details",
      description: "A content and all its details",
      type: :object,
      properties: %{
        content: %Schema{anyOf: [Content]},
        content_type: %Schema{anyOf: [WraftDocWeb.Schemas.ContentType.ContentTypeAndLayout]},
        state: %Schema{anyOf: [WraftDocWeb.Schemas.State.State]},
        creator: %Schema{anyOf: [WraftDocWeb.Schemas.User.User]}
      },
      example: %{
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
      }
    })
  end

  defmodule ContentsAndContentTypeAndState do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Instances, their content types and states",
      description: "IInstances and all its details except creator.",
      type: :array,
      items: ContentAndContentTypeAndState
    })
  end

  defmodule ContentsIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Contents Index",
      description: "List of contents",
      type: :object,
      properties: %{
        contents: ContentsAndContentTypeAndState,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
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
        name: %Schema{type: :string, description: "Vendors name"},
        email: %Schema{type: :string, description: "Vendors email"},
        phone: %Schema{type: :string, description: "Phone number"},
        address: %Schema{type: :string, description: "The Address of the vendor"},
        gstin: %Schema{type: :string, description: "The Gstin of the vendor"},
        reg_no: %Schema{type: :string, description: "The RegNo of the vendor"},
        contact_person: %Schema{type: :string, description: "The ContactPerson of the vendor"}
      },
      example: %{
        name: "Vos Services",
        email: "serv@vosmail.com",
        phone: "98565262262",
        address: "rose boru, hourbures",
        gstin: "32ADF22SDD2DFS32SDF",
        reg_no: "ASD21122",
        contact_person: "vikas abu"
      }
    })
  end

  defmodule LockUnlockRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Lock unlock request",
      description: "request to lock or unlock",
      type: :object,
      properties: %{
        editable: %Schema{type: :boolean, description: "Editable"}
      },
      required: [:editable],
      example: %{
        editable: true
      }
    })
  end

  defmodule Change do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "List of changes",
      description: "Lists the chenges on a version",
      type: :object,
      properties: %{
        ins: %Schema{type: :array, items: %Schema{type: :string}},
        del: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{
        ins: ["testing version succesufll"],
        del: ["testing version"]
      }
    })
  end

  defmodule BuildRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Build request",
      description: "Request to build a document",
      type: :object,
      properties: %{
        naration: %Schema{type: :string, description: "Naration for this version"}
      },
      example: %{
        naration: "New year edition"
      }
    })
  end

  defmodule ContentEmailResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Email sent response",
      description: "Response for document instance email sent",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      example: %{
        info: "Email sent successfully"
      }
    })
  end

  defmodule DocumentInstanceMailer do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Document Instance Email",
      description: "Api to send email for a given document instance",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email"},
        subject: %Schema{type: :string, description: "Subject"},
        message: %Schema{type: :string, description: "Message"},
        cc: %Schema{type: :array, items: %Schema{type: :string}, description: "Emails"}
      },
      required: [:email, :subject, :message],
      example: %{
        email: "example@example.com",
        subject: "Subject of the email",
        message: "Body of the email",
        cc: ["cc1@example.com", "cc2@example.com"]
      }
    })
  end

  defmodule InviteDocumentRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Share document request",
      description: "Request to share a document",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email"},
        role: %Schema{type: :string, description: "Role", enum: ["suggestor", "viewer"]}
      },
      required: [:email, :role],
      example: %{
        email: "example@example.com",
        role: "suggestor"
      }
    })
  end

  defmodule VerifyDocumentInviteTokenResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Verify document invite token response",
      description: "Response for document invite token verification",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      example: %{
        info: "Invite token verified successfully"
      }
    })
  end

  defmodule MetaUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Meta update request",
      description: "Meta update request",
      type: :object,
      properties: %{
        meta: %Schema{type: :object, description: "Meta"}
      },
      required: [:meta],
      example: %{
        type: "contract",
        status: "draft",
        expiry_date: "2020-02-21",
        contract_value: 100_000.0,
        counter_parties: ["Vos Services"],
        clauses: [],
        reminder: []
      }
    })
  end

  defmodule ContractMetrics do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Contract Metrics",
      description: "Contract metrics for a specific time interval",
      type: :object,
      properties: %{
        datetime: %Schema{
          type: :string,
          description: "ISO8601 datetime representing the start of the interval",
          format: "date-time",
          example: "2024-04-01T00:00:00Z"
        },
        total: %Schema{
          type: :integer,
          description: "Total number of contracts in this interval",
          minimum: 0,
          example: 25
        },
        confirmed: %Schema{
          type: :integer,
          description: "Number of confirmed contracts (approval_status: true)",
          minimum: 0,
          example: 18
        },
        pending: %Schema{
          type: :integer,
          description: "Number of pending contracts (total - confirmed)",
          minimum: 0,
          example: 7
        }
      }
    })
  end

  defmodule ContractChart do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Contract Chart Response",
      description: "Contract analytics data grouped by time intervals",
      type: :object,
      properties: %{
        contract_list: %Schema{
          type: :array,
          description: "List of contract metrics by time interval",
          items: ContractMetrics
        }
      },
      example: %{
        contract_list: [
          %{
            datetime: "2024-04-01T00:00:00Z",
            total: 25,
            total_amount: 0,
            confirmed: 18,
            pending: 7
          },
          %{
            datetime: "2024-04-08T00:00:00Z",
            total: 32,
            total_amount: 0,
            confirmed: 24,
            pending: 8
          }
        ]
      }
    })
  end

  defmodule VersionComparison do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Version Comparison",
      description: "Comparison data between two versions",
      type: :object,
      properties: %{
        version_1: %Schema{
          type: :object,
          description: "Details of the first version for comparison"
        },
        version_2: %Schema{
          type: :object,
          description: "Details of the second version for comparison"
        }
      },
      required: [:version_1, :version_2],
      example: %{
        "version 1": %{
          id: "ccd54c60-49eb-449b-825a-02c9fa5a88aa",
          serialized: %{
            body: "item 1\n\nitem 1\n\nitem 1...",
            fields: "{\"name\":\"Faheem\",\"title\":\"Technical & Commercial Proposal\",...",
            serialized: "{\"type\":\"doc\",\"content\":[...]}",
            title: "Contract for [clientName]"
          }
        },
        "version 2": %{
          id: "bb195fc4-5bab-435e-8498-480a7d904c03",
          serialized: %{
            body: "item 1\n\nitem 1\n\nitem 1...",
            fields: "{\"name\":\"Faheem\",\"title\":\"Technical & Commercial Proposal\",...",
            serialized: "{\"type\":\"doc\",\"content\":[...]}",
            title: "Contract for [clientName]"
          }
        }
      }
    })
  end

  defmodule VersionResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Version Response",
      description: "Response containing details of an updated version",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the version"},
        version_number: %Schema{type: :integer, description: "Version number"},
        raw: %Schema{type: :string, description: "Raw data of the version"},
        serialised: %Schema{type: :object, description: "Serialized data of the version"},
        naration: %Schema{type: :string, description: "Narration for the version"},
        author: %Schema{type: :object, description: "Author of the version"},
        current_version: %Schema{
          type: :boolean,
          description: "Whether this is the current version"
        },
        inserted_at: %Schema{
          type: :string,
          description: "When the version was created",
          format: "ISO-8601"
        }
      },
      required: [:id, :version_number, :author],
      example: [
        %{
          id: "123456",
          version_number: 2,
          current_version: true,
          inserted_at: "2023-01-01T12:00:00Z"
        }
      ]
    })
  end

  defmodule PaginatedVersionResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Paginated Version Response",
      description: "Response containing a paginated list of versions",
      type: :object,
      properties: %{
        entries: %Schema{type: :array, items: VersionResponse, description: "List of versions"},
        page_number: %Schema{type: :integer, description: "Current page number"},
        page_size: %Schema{type: :integer, description: "Number of items per page"},
        total_entries: %Schema{type: :integer, description: "Total number of versions"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"}
      },
      required: [:entries, :page_number, :page_size, :total_entries, :total_pages],
      example: %{
        entries: [
          %{
            id: "123456",
            version_number: 2,
            current_version: true,
            inserted_at: "2023-01-01T12:00:00Z"
          },
          %{
            id: "789012",
            version_number: 1,
            current_version: false,
            inserted_at: "2023-01-01T10:00:00Z"
          }
        ],
        page_number: 1,
        page_size: 10,
        total_entries: 2,
        total_pages: 1
      }
    })
  end

  defmodule RestoreContent do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Restore Content",
      description: "Response after restoring an instance to a previous version",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Status message"},
        content: %Schema{type: :object, description: "Restored instance details"}
      },
      required: [:info, :content],
      example: %{
        info: "Instance version restored",
        content: %{
          id: "1232148nb3478",
          name: "Sample Document",
          state: "draft",
          version: 2
        }
      }
    })
  end

  defmodule Log do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Instance Log entity",
      description: "Logs of actions performed on an instance",
      type: :object,
      example: [
        %{
          id: "4e630a83-c8d8-43d6-875e-0a2a47ec97f5",
          action: "update",
          document_id: "4e630a83-c8d8-43d6-875e-0a2a47ec97f5",
          inserted_at: "2023-05-15T14:32:10Z",
          actor: %{
            current_org_id: "4e630a83-c8d8-43d6-875e-0a2a4747838",
            name: "John Doe",
            email: "john@example.com"
          }
        }
      ]
    })
  end

  defmodule Logs do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Instance Logs",
      description: "Logs of actions performed on an instance",
      type: :object,
      properties: %{
        entries: %Schema{type: :array, items: Log, description: "List of versions"},
        page_number: %Schema{type: :integer, description: "Current page number"},
        page_size: %Schema{type: :integer, description: "Number of items per page"},
        total_entries: %Schema{type: :integer, description: "Total number of versions"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"}
      },
      required: [:entries, :page_number, :page_size, :total_entries, :total_pages],
      example: %{
        entries: [
          %{
            id: "4e630a83-c8d8-43d6-875e-0a2a47ec97f5",
            action: "update",
            document_id: "4e630a83-c8d8-43d6-875e-0a2a47ec97f5",
            inserted_at: "2023-05-15T14:32:10Z",
            actor: %{
              current_org_id: "4e630a83-c8d8-43d6-875e-0a2a4747838",
              name: "John Doe",
              email: "john@example.com"
            }
          }
        ],
        page_number: 1,
        page_size: 10,
        total_entries: 2,
        total_pages: 1
      }
    })
  end
end
