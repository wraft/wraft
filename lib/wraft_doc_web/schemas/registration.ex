defmodule WraftDocWeb.Schemas.Registration do
  @moduledoc """
  Schema for Registration request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule UserRegisterRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Register User",
      description: "A user to be registered in the application",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "User's name"},
        email: %Schema{type: :string, description: "User's email"},
        password: %Schema{type: :string, description: "User's password"},
        token: %Schema{type: :string, description: "Organisation invite token"},
        profile_pic: %Schema{type: :string, format: :binary, description: "Profile pic"}
      },
      required: [:name, :email, :password],
      example: %{
        name: "John Doe",
        email: "email@xyz.com",
        password: "Password"
      }
    })
  end
end
