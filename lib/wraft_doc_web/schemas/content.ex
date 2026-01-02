defmodule WraftDocWeb.Schemas.Content do
  @moduledoc """
  Schema for Content request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias WraftDocWeb.Schemas.{
    ContentType,
    InstanceApprovalSystem,
    State,
    User,
    Vendor
  }

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

  defmodule Content do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content",
      description: "A content instance details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the content"},
        instance_id: %Schema{type: :string, description: "A unique ID generated for the content"},
        meta: %Schema{type: :object, description: "Meta data of the content"},
        approval_status: %Schema{type: :boolean, description: "Approval status"},
        raw: %Schema{type: :string, description: "Raw data of the content"},
        serialized: %Schema{type: :object, description: "Serialized data of the content"},
        build: %Schema{type: :string, description: "URL of the build document"},
        signed_doc_url: %Schema{type: :string, description: "URL of the signed document"},
        editable: %Schema{type: :boolean, description: "Is the content editable"},
        vendor: Vendor,
        inserted_at: %Schema{type: :string, format: "ISO-8601"},
        updated_at: %Schema{type: :string, format: "ISO-8601"}
      },
      required: [:id],
      example: %{
        id: "1232148nb3478",
        instance_id: "OFFL01",
        meta: %{},
        approval_status: false,
        raw: "Content",
        serialized: %{title: "Title of the content", body: "Body of the content"},
        build: "/uploads/OFFL01/OFFL01-v1.pdf",
        signed_doc_url: "/uploads/OFFL01/OFFL01-signed.pdf",
        editable: true,
        vendor: %{
          name: "Vos Services",
          email: "serv@vosmail.com"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ContentSummary do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content Summary",
      description: "Summary of a content instance",
      type: :object,
      properties: %{
        content: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string},
            instance_id: %Schema{type: :string},
            meta: %Schema{type: :object},
            raw: %Schema{type: :string},
            approval_status: %Schema{type: :boolean},
            type: %Schema{type: :string},
            serialized: %Schema{type: :object},
            vendor: Vendor,
            inserted_at: %Schema{type: :string},
            updated_at: %Schema{type: :string}
          }
        },
        content_type: ContentType.ContentTypeWithoutFields,
        state: State.State,
        instance_approval_systems: %Schema{
          type: :array,
          items: InstanceApprovalSystem.InstanceApprovalSystem
        },
        profile_pic: %Schema{type: :string, nullable: true},
        creator: User.UserIdAndName
      }
    })
  end

  defmodule ContentsIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Contents Index",
      description: "List of contents",
      type: :object,
      properties: %{
        contents: %Schema{type: :array, items: ContentSummary},
        page_number: %Schema{type: :integer},
        total_pages: %Schema{type: :integer},
        total_entries: %Schema{type: :integer}
      }
    })
  end

  defmodule PendingApprovalContent do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Pending Approval Content",
      type: :object,
      properties: %{
        content: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string},
            instance_id: %Schema{type: :string},
            raw: %Schema{type: :string},
            title: %Schema{type: :string},
            previous_state: %Schema{type: :string},
            next_state: %Schema{type: :string},
            inserted_at: %Schema{type: :string},
            updated_at: %Schema{type: :string}
          }
        },
        state: State.State,
        creator: User.UserIdAndName
      }
    })
  end

  defmodule InstanceApprovals do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "InstanceApprovals",
      description: "Get list of pending approvals for current user",
      type: :object,
      properties: %{
        pending_approvals: %Schema{type: :array, items: PendingApprovalContent},
        page_number: %Schema{type: :integer},
        total_pages: %Schema{type: :integer},
        total_entries: %Schema{type: :integer}
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
        vendor_id: %Schema{type: :string, description: "Vendor ID"},
        doc_settings: %Schema{type: :object, description: "Document settings"}
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
        raw: %Schema{type: :string},
        serialized: %Schema{type: :string},
        naration: %Schema{type: :string},
        vendor_id: %Schema{type: :string}
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

  defmodule VersionResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Version Response",
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        version_number: %Schema{type: :integer},
        raw: %Schema{type: :string},
        serialised: %Schema{type: :object},
        naration: %Schema{type: :string},
        author: %Schema{type: :object},
        current_version: %Schema{type: :boolean},
        inserted_at: %Schema{type: :string}
      },
      example: %{
        id: "123456",
        version_number: 2,
        current_version: true,
        inserted_at: "2023-01-01T12:00:00Z",
        author: %{
          id: "123",
          name: "John Doe"
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
        content: Content,
        content_type: ContentType.ContentTypeAndLayout,
        state: State.State,
        creator: User.User,
        profile_pic: %Schema{type: :string, nullable: true},
        vendor: Vendor,
        versions: %Schema{type: :array, items: VersionResponse},
        instance_approval_systems: %Schema{
          type: :array,
          items: InstanceApprovalSystem.InstanceApprovalSystem
        }
      }
    })
  end

  defmodule LockUnlockRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Lock unlock request",
      type: :object,
      properties: %{
        editable: %Schema{type: :boolean}
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
      type: :object,
      properties: %{
        naration: %Schema{type: :string}
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
      type: :object,
      properties: %{
        info: %Schema{type: :string}
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
      type: :object,
      properties: %{
        email: %Schema{type: :string},
        subject: %Schema{type: :string},
        message: %Schema{type: :string},
        cc: %Schema{type: :array, items: %Schema{type: :string}}
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

  defmodule MetaUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Meta update request",
      type: :object,
      properties: %{
        meta: %Schema{type: :object}
      },
      required: [:meta],
      example: %{
        type: "contract",
        status: "draft"
      }
    })
  end

  defmodule ContractMetrics do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Contract Metrics",
      type: :object,
      properties: %{
        datetime: %Schema{type: :string, format: "date-time"},
        total: %Schema{type: :integer},
        confirmed: %Schema{type: :integer},
        pending: %Schema{type: :integer}
      }
    })
  end

  defmodule ContractChart do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Contract Chart Response",
      type: :array,
      items: ContractMetrics
    })
  end

  defmodule PaginatedVersionResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Paginated Version Response",
      type: :object,
      properties: %{
        entries: %Schema{type: :array, items: VersionResponse},
        page_number: %Schema{type: :integer},
        page_size: %Schema{type: :integer},
        total_entries: %Schema{type: :integer},
        total_pages: %Schema{type: :integer}
      }
    })
  end

  defmodule RestoreContent do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Restore Content",
      type: :object,
      properties: %{
        info: %Schema{type: :string},
        content: Content
      }
    })
  end

  defmodule Log do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Instance Log entity",
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        action: %Schema{type: :string},
        actor: %Schema{type: :object},
        message: %Schema{type: :string},
        inserted_at: %Schema{type: :string, format: "ISO-8601"}
      }
    })
  end

  defmodule Logs do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Instance Logs",
      type: :object,
      properties: %{
        entries: %Schema{type: :array, items: Log},
        page_number: %Schema{type: :integer},
        page_size: %Schema{type: :integer},
        total_entries: %Schema{type: :integer},
        total_pages: %Schema{type: :integer}
      }
    })
  end

  defmodule BuildFail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Build Fail",
      type: :object,
      properties: %{
        info: %Schema{type: :string},
        error: %Schema{type: :string},
        exit_code: %Schema{type: :integer}
      }
    })
  end

  defmodule CheckToken do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Check Token",
      type: :object,
      properties: %{
        info: %Schema{type: :string}
      }
    })
  end

  defmodule MetaResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Meta Response",
      type: :object,
      properties: %{
        meta: %Schema{type: :object}
      }
    })
  end

  defmodule ApproveRejectResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Approve Reject Response",
      type: :object,
      properties: %{
        content: Content,
        content_type: ContentType.ContentTypeAndLayout,
        state: State.State,
        creator: User.User,
        profile_pic: %Schema{type: :string, nullable: true},
        versions: %Schema{type: :array, items: VersionResponse}
      }
    })
  end
end
