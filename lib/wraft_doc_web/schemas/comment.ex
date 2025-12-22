defmodule WraftDocWeb.Schemas.Comment do
  @moduledoc """
  Schema for Comment request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule CommentRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Comment Request",
      description: "Create comment request.",
      type: :object,
      properties: %{
        comment: %Schema{type: :string, description: "The Comment to post"},
        meta: %Schema{type: :object, description: "Meta data of inline comments"},
        is_parent: %Schema{type: :boolean, description: "Declare the comment is parent or child"},
        parent_id: %Schema{type: :string, description: "Parent id of a child comment"},
        master: %Schema{type: :string, description: "Comments master"},
        master_id: %Schema{type: :string, description: "Document id of the comment"}
      },
      required: [:comment, :is_parent, :parent_id, :master, :master_id],
      example: %{
        comment: "a sample comment",
        is_parent: true,
        parent_id: nil,
        master: "instance",
        meta: %{block: "introduction", line: 12},
        master_id: "32232sdffasdfsfdfasdfsdfs"
      }
    })
  end

  defmodule Comment do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Comment",
      description: "A Comment",
      type: :object,
      properties: %{
        comment: %Schema{type: :string, description: "Posted comment"},
        meta: %Schema{type: :object, description: "Meta data of inline comments"},
        is_parent: %Schema{type: :boolean, description: "Parent or child comment"},
        parent_id: %Schema{type: :string, description: "The ParentId of the comment"},
        master: %Schema{type: :string, description: "The Master of the comment"},
        master_id: %Schema{type: :string, description: "The MasterId of the comment"},
        children: %Schema{
          type: :array,
          description: "Children of the comment",
          items: %Schema{type: :object}
        },
        inserted_at: %Schema{
          type: :string,
          description: "When was the comment inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the comment last updated",
          format: "ISO-8601"
        }
      },
      required: [:comment, :is_parent, :parent_id, :master, :master_id, :children],
      example: %{
        comment: "a sample comment",
        is_parent: true,
        master: "instance",
        meta: %{block: "introduction", line: 12},
        master_id: "sdf15511551sdf",
        user_id: "asdf2s2dfasd2",
        organisation_id: "451s51dfsdf515",
        children: [
          %{
            comment: "a sample comment",
            is_parent: true,
            master: "instance",
            meta: %{block: "introduction", line: 12},
            master_id: "sdf15511551sdf",
            user_id: "asdf2s2dfasd2",
            organisation_id: "451s51dfsdf515",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule Comments do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Comment list",
      type: :array,
      items: Comment
    })
  end

  defmodule CommentIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Comment Index",
      type: :object,
      properties: %{
        comments: Comments,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        comments: [
          %{
            comment: "a sample comment",
            meta: %{block: "introduction", line: 12},
            is_parent: true,
            master: "instance",
            master_id: "sdf15511551sdf",
            user_id: "asdf2s2dfasd2",
            organisation_id: "451s51dfsdf515",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            children: [
              %{
                comment: "a sample comment",
                is_parent: true,
                master: "instance",
                meta: %{block: "introduction", line: 12},
                master_id: "sdf15511551sdf",
                user_id: "asdf2s2dfasd2",
                organisation_id: "451s51dfsdf515",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ]
          },
          %{
            comment: "a sample comment",
            meta: %{block: "introduction", line: 12},
            is_parent: true,
            master: "instance",
            master_id: "sdf15511551sdf",
            user_id: "asdf2s2dfasd2",
            organisation_id: "451s51dfsdf515",
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
end
