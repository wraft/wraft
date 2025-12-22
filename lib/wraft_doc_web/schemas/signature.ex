defmodule WraftDocWeb.Schemas.Signature do
  @moduledoc """
  OpenAPI schemas for Signature operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule CounterPartyRequest do
    @moduledoc """
    Schema for counter party request
    """
    OpenApiSpex.schema(%{
      title: "Counter Party Request",
      description: "Request for a counter party to sign a document",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the signatory"},
        email: %Schema{type: :string, format: :email, description: "Email of the signatory"},
        signature_image: %Schema{
          type: :string,
          description: "Base64 encoded signature image"
        },
        signature_type: %Schema{
          type: :string,
          enum: ["digital", "electronic", "handwritten"],
          description: "Type of signature"
        },
        color_rgb: %Schema{
          type: :object,
          description: "Color of the signature",
          properties: %{
            r: %Schema{type: :integer, description: "Red component (0-255)"},
            g: %Schema{type: :integer, description: "Green component (0-255)"},
            b: %Schema{type: :integer, description: "Blue component (0-255)"}
          }
        }
      },
      required: [:name, :email, :color_rgb],
      example: %{
        name: "John Doe",
        email: "john.doe@example.com",
        signature_image: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
        signature_type: "handwritten",
        color_rgb: %{"r" => 255, "g" => 255, "b" => 255}
      }
    })
  end

  defmodule SignatureResponse do
    @moduledoc """
    Schema for signature response
    """
    OpenApiSpex.schema(%{
      title: "Signature",
      description: "Digital signature information",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Signature ID"},
        signature_type: %Schema{type: :string, description: "Type of signature"},
        signature_date: %Schema{
          type: :string,
          format: :"date-time",
          description: "Date of signature"
        },
        is_valid: %Schema{type: :boolean, description: "Is the signature valid"},
        verification_token: %Schema{
          type: :string,
          description: "Token for signature verification"
        },
        instance: %Schema{type: :object, description: "Document instance"},
        counterparty: %Schema{type: :object, description: "Counterparty information"}
      },
      example: %{
        id: "123e4567-e89b-12d3-a456-426614174000",
        signature_type: "digital",
        signature_date: "2023-01-01T00:00:00Z",
        is_valid: true,
        verification_token: "abc123",
        instance: %{
          id: "123e4567-e89b-12d3-a456-426614174000",
          title: "Document Title"
        },
        counter_party: %{
          name: "John Doe",
          email: "john.doe@example.com"
        }
      }
    })
  end

  defmodule SignaturesList do
    @moduledoc """
    Schema for list of signatures
    """
    OpenApiSpex.schema(%{
      title: "Signatures",
      description: "List of signatures",
      type: :object,
      properties: %{
        signatures: %Schema{
          type: :array,
          description: "List of signatures",
          items: SignatureResponse
        }
      },
      example: %{
        signatures: [
          %{
            id: "123e4567-e89b-12d3-a456-426614174000",
            signature_type: "digital",
            signature_date: "2023-01-01T00:00:00Z",
            is_valid: true,
            verification_token: "abc123",
            instance: %{
              id: "123e4567-e89b-12d3-a456-426614174000",
              title: "Document Title"
            },
            counter_party: %{
              name: "John Doe",
              email: "john.doe@example.com"
            }
          }
        ]
      }
    })
  end

  defmodule SignatureProcess do
    @moduledoc """
    Schema for processing a signature
    """
    OpenApiSpex.schema(%{
      title: "Process Signature",
      description: "Process a digital signature",
      type: :object,
      properties: %{
        signature_data: %Schema{
          type: :object,
          description: "Signature data (could be image data or other format)"
        },
        signature_position: %Schema{type: :object, description: "Position in the document"},
        file: %Schema{type: :string, description: "URL of the uploaded file"},
        token: %Schema{type: :string, description: "Verification token"},
        signature_type: %Schema{
          type: :string,
          enum: ["digital", "electronic", "handwritten"],
          description: "Type of signature"
        }
      },
      required: [:signature_data, :token, :signature_type],
      example: %{
        file: "/signature.pdf",
        signature_type: "digital",
        verification_token: "abc123",
        signature_data: %{},
        signature_position: %{
          "x" => 100,
          "y" => 200
        }
      }
    })
  end

  defmodule SignedPdfResponse do
    @moduledoc """
    Schema for signed PDF response
    """
    OpenApiSpex.schema(%{
      title: "Signed PDF Response",
      description: "Response with URL to the signed PDF",
      type: :object,
      properties: %{
        signed_pdf_url: %Schema{type: :string, description: "URL to the signed PDF"},
        message: %Schema{type: :string, description: "Success message"}
      },
      required: [:signed_pdf_url],
      example: %{
        signed_pdf_url: "https://example.com/signed_document.pdf",
        message: "Visual signature applied successfully"
      }
    })
  end

  defmodule CounterPartiesList do
    @moduledoc """
    Schema for list of counterparties
    """
    OpenApiSpex.schema(%{
      title: "Counter Parties List",
      description: "List of counterparties for a document",
      type: :object,
      properties: %{
        counterparties: %Schema{
          type: :array,
          description: "List of counterparties",
          items: %Schema{type: :object}
        }
      },
      example: %{
        counterparties: [
          %{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "John Doe",
            email: "john.doe@example.com"
          }
        ]
      }
    })
  end

  defmodule CreateSignatureRequest do
    @moduledoc """
    Schema for creating a signature request
    """
    OpenApiSpex.schema(%{
      title: "Create Signature Request",
      description: "Request to create a signature record for an existing counterparty",
      type: :object,
      properties: %{
        counter_party_id: %Schema{
          type: :string,
          format: :uuid,
          description: "ID of the counterparty"
        }
      },
      required: [:counter_party_id],
      example: %{
        counter_party_id: "123e4567-e89b-12d3-a456-426614174000"
      }
    })
  end

  defmodule AssignCounterPartyRequest do
    @moduledoc """
    Schema for assigning a counter party to a signature
    """
    OpenApiSpex.schema(%{
      title: "Assign Counter Party Request",
      description: "Request to assign a counter party to a signature",
      type: :object,
      properties: %{
        counterparty_id: %Schema{
          type: :string,
          format: :uuid,
          description: "Counter party ID to assign"
        }
      },
      required: [:counterparty_id],
      example: %{
        counterparty_id: "123e4567-e89b-12d3-a456-426614174000"
      }
    })
  end
end
