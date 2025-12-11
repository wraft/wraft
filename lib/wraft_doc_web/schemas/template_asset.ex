defmodule WraftDocWeb.Schemas.TemplateAsset do
  @moduledoc """
  Schema for TemplateAsset request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule TemplateAsset do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Template Asset",
      description: "A Template asset bundle.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the template asset", format: "uuid"},
        name: %Schema{type: :string, description: "Name of the template asset"},
        file: %Schema{type: :string, description: "URL of the uploaded file"},
        inserted_at: %Schema{
          type: :string,
          description: "When the template asset was inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When the template asset was last updated",
          format: "ISO-8601"
        }
      },
      required: [:id],
      example: %{
        id: "1232148nb3478",
        name: "Template Asset",
        file: "/contract.zip",
        file_entries: [
          "wraft.json",
          "theme/HubotSans-RegularItalic.otf",
          "theme/HubotSans-Regular.otf",
          "theme/HubotSans-BoldItalic.otf",
          "theme/HubotSans-Bold.otf",
          "theme/",
          "template.json",
          "layout/gradient.pdf",
          "layout/",
          "contract/template.tex",
          "contract/"
        ],
        wraft_json: %{
          data_template: "data_template/",
          layout: "layout/gradient.pdf",
          flow: "flow/",
          theme: "theme/",
          contract: "contract/"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ShowTemplateAsset do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show template asset",
      description: "A template asset and its details",
      type: :object,
      properties: %{
        template_asset: TemplateAsset,
        creator: WraftDocWeb.Schemas.User.User
      },
      example: %{
        template_asset: %{
          id: "1232148nb3478",
          name: "Template Asset",
          file: "/contract.zip",
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

  defmodule TemplateAssets do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All template assets in an organisation",
      description: "All template assets that have been created under an organisation",
      type: :array,
      items: TemplateAsset
    })
  end

  defmodule TemplateAssetsIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Template Assets Index",
      type: :object,
      properties: %{
        template_assets: TemplateAssets,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        template_assets: [
          %{
            id: "1232148nb3478",
            name: "Template Asset",
            file: "/contract.zip",
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

  defmodule PublicTemplateList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Public Template List",
      description: "A list of public templates, each with a file name and path.",
      type: :object,
      properties: %{
        templates: %Schema{
          type: :array,
          description: "List of templates with file name and path",
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, description: "Template asset id"},
              name: %Schema{type: :string, description: "Template asset name"},
              description: %Schema{
                type: :string,
                description: "Template asset description"
              },
              file_name: %Schema{type: :string, description: "The name of the file"},
              zip_file_url: %Schema{
                type: :string,
                description: "URL of the zip file in the template asset"
              },
              thumbnail_url: %Schema{
                type: :string,
                description: "URL of the thumbnail image of the template asset"
              }
            }
          }
        }
      },
      example: %{
        templates: [
          %{
            id: "53d2de6d-e0ad-4c5a-a302-6af54fa36920",
            name: "Contract",
            description: "description",
            file_name: "contract",
            file_size: "94.38 KB",
            thumbnail_url:
              "http://minio.example.com/wraft/public/templates/contract-template/thumbnail.png",
            zip_file_url:
              "http://minio.example.com/wraft/public/templates/contract-template/zip_file.zip"
          },
          %{
            id: "53d2de6d-e0ad-4c5a-a302-6af54fa36920",
            name: "Contract",
            description: "description",
            file_name: "contract",
            file_size: "94.38 KB",
            thumbnail_url:
              "http://minio.example.com/wraft/public/templates/contract-template/thumbnail.png",
            zip_file_url:
              "http://minio.example.com/wraft/public/templates/contract-template/zip_file.zip"
          }
        ]
      }
    })
  end

  defmodule DownloadTemplateResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Download Template Response",
      description: "Response containing the pre-signed URL for downloading the template.",
      type: :object,
      properties: %{
        template_url: %Schema{
          type: :string,
          description: "Pre-signed URL for downloading the template",
          example:
            "https://minio.example.com/bucket/templates/example-template.zip?X-Amz-Signature=..."
        }
      }
    })
  end

  defmodule FileDownloadResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "File Download Response",
      description: "Response for a file download.",
      type: :string,
      format: :binary,
      example: "Binary data representing the downloaded file."
    })
  end

  defmodule TemplateImport do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Template Import Response",
      description: "Response containing details of imported template components",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "Status message of the import operation"},
        items: %Schema{
          type: :array,
          description: "List of imported template components",
          items: %Schema{
            type: :object,
            properties: %{
              item_type: %Schema{
                type: :string,
                description: "Type of the imported item",
                enum: ["flow", "data_template", "layout", "theme", "variant"]
              },
              id: %Schema{
                type: :string,
                description: "Unique identifier of the imported item",
                format: "uuid"
              },
              name: %Schema{
                type: :string,
                description: "Name of the imported item (for most item types)"
              },
              title: %Schema{
                type: :string,
                description: "Title of the imported item (for data_template)"
              },
              created_at: %Schema{
                type: :string,
                description: "Timestamp of item creation",
                format: "date-time"
              }
            }
          }
        }
      },
      example: %{
        message: "Template imported successfully",
        items: [
          %{
            item_type: "flow",
            id: "dc0c7d4c-1328-45c0-ba3b-af841f7f5b59",
            name: "Contract flow 23",
            created_at: "2024-11-26T21:18:35"
          },
          %{
            item_type: "data_template",
            id: "98f49a33-5a5f-4455-910c-11f7f3e1a575",
            title: "Contract 33",
            created_at: "2024-11-26T21:18:36"
          }
        ]
      }
    })
  end

  defmodule TemplatePreImport do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Template Pre-Import Response",
      description:
        "Response containing existing and missing items for template import preparation",
      type: :object,
      properties: %{
        missing_items: %Schema{
          type: :array,
          description: "List of item types missing from the template asset",
          items: %Schema{
            type: :string,
            enum: ["layout", "theme", "flow", "data_template", "variant"]
          }
        },
        existing_items: %Schema{
          type: :object,
          description: "Details of existing items in the template asset",
          properties: %{
            data_template: %Schema{
              type: :object,
              description: "Existing data template details",
              properties: %{
                title: %Schema{type: :string, description: "Title of the data template"},
                title_template: %Schema{type: :string, description: "Template for the title"}
              }
            },
            variant: %Schema{
              type: :object,
              description: "Existing variant details",
              properties: %{
                name: %Schema{type: :string, description: "Name of the variant"},
                description: %Schema{type: :string, description: "Description of the variant"},
                prefix: %Schema{type: :string, description: "Prefix for the variant"}
              }
            }
          }
        }
      },
      example: %{
        missing_items: ["layout", "theme", "flow"],
        existing_items: %{
          data_template: %{
            title: "Contract",
            title_template: "Contract for [clientName]"
          },
          variant: %{
            name: "Contract",
            description: "Variant for contract layouts",
            prefix: "CTR"
          }
        }
      }
    })
  end
end
