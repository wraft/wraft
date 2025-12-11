defmodule WraftDocWeb.Schemas.WaitingList do
  @moduledoc """
  Schema for WaitingList request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule WaitingListRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Join Waiting list",
      description: "Join user to the waiting list",
      type: :object,
      properties: %{
        first_name: %Schema{type: :string, description: "User's first name"},
        last_name: %Schema{type: :string, description: "User's last name"},
        email: %Schema{type: :string, description: "User's email"}
      },
      required: [:first_name, :last_name, :email],
      example: %{
        first_name: "first name",
        last_name: "last name",
        email: "sample@gmail.com"
      }
    })
  end

  defmodule WaitingListResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Join Waiting list Info",
      description: "Join Waiting list info",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      example: %{
        info: "Success"
      }
    })
  end
end
