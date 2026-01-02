defmodule WraftDocWeb.Schemas.Comment do
  @moduledoc """
  Schema for Comment request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.{Profile, User}

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
      required: [:comment, :is_parent, :master, :master_id],
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
        id: %Schema{type: :string, description: "Comment ID"},
        comment: %Schema{type: :string, description: "Posted comment"},
        meta: %Schema{type: :object, description: "Meta data of inline comments"},
        is_parent: %Schema{type: :boolean, description: "Parent or child comment"},
        parent_id: %Schema{type: :string, description: "The ParentId of the comment"},
        master: %Schema{type: :string, description: "The Master of the comment"},
        master_id: %Schema{type: :string, description: "The MasterId of the comment"},
        resolved?: %Schema{type: :boolean, description: "Is the comment resolved"},
        resolved_by: User.User,
        user: User.User,
        profile: Profile.Profile,
        reply_count: %Schema{type: :integer, description: "Number of replies"},
        doc_version_id: %Schema{type: :string, description: "Document version ID"},
        children: %Schema{
          type: :array,
          description: "Children of the comment",
          # Recursive definition workaround
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
      required: [:id, :comment, :is_parent, :master, :master_id],
      example: %{
        id: "comment_123",
        comment: "a sample comment",
        is_parent: true,
        master: "instance",
        meta: %{block: "introduction", line: 12},
        master_id: "sdf15511551sdf",
        resolved?: false,
        reply_count: 1,
        user: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        profile: %{
          name: "Jhone",
          dob: "1992-09-24",
          gender: "Male",
          profile_pic: "/image.png",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        children: [
          %{
            id: "comment_124",
            comment: "a sample reply",
            is_parent: false,
            parent_id: "comment_123",
            master: "instance",
            meta: %{block: "introduction", line: 12},
            master_id: "sdf15511551sdf",
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
      items: Comment,
      example: [
        %{
          id: "comment_123",
          comment: "a sample comment",
          is_parent: true,
          master: "instance",
          meta: %{block: "introduction", line: 12},
          master_id: "sdf15511551sdf",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      ]
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
            id: "comment_123",
            comment: "a sample comment",
            meta: %{block: "introduction", line: 12},
            is_parent: true,
            master: "instance",
            master_id: "sdf15511551sdf",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            children: []
          }
        ],
        page_number: 1,
        total_pages: 1,
        total_entries: 1
      }
    })
  end

  defmodule DeleteCommentResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Delete Comment Response",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Comment ID"},
        comment: %Schema{type: :string, description: "Posted comment"},
        is_parent: %Schema{type: :boolean, description: "Parent or child comment"},
        parent_id: %Schema{type: :string, description: "The ParentId of the comment"},
        master: %Schema{type: :string, description: "The Master of the comment"},
        master_id: %Schema{type: :string, description: "The MasterId of the comment"},
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
      example: %{
        id: "comment_123",
        comment: "a sample comment",
        is_parent: true,
        parent_id: nil,
        master: "instance",
        master_id: "sdf15511551sdf",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end
end
