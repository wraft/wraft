defmodule WraftDocWeb.Schemas.Profile do
  @moduledoc """
  Schema for Profile request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule UserForProfile do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User",
      description: "User login details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "User id"},
        email: %Schema{type: :string, description: "Email id"}
      },
      example: %{
        id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
        email: "admin@wraftdocs.com"
      }
    })
  end

  defmodule ProfileRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Profile Request",
      description: "User profile details to create",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the user"},
        dob: %Schema{type: :string, description: "Date of birth", format: "date"},
        profile_pic: %Schema{type: :string, description: "path to profile pic"},
        gender: %Schema{type: :string, description: "Users gender"}
      },
      required: [:name],
      example: %{
        name: "Jhone",
        dob: "1992-09-24",
        gender: "Male",
        profile_pic: "/image.png"
      }
    })
  end

  defmodule Profile do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Profile",
      description: "Profile details",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the user"},
        dob: %Schema{type: :string, description: "Date of birth", format: "date"},
        gender: %Schema{type: :string, description: "Users gender"},
        profile_pic: %Schema{type: :string, description: "path to profile pic"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the user inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the user last updated",
          format: "ISO-8601"
        },
        user: UserForProfile
      },
      required: [:name],
      example: %{
        name: "Jhone",
        dob: "1992-09-24",
        gender: "Male",
        profile_pic: "/image.png",
        user: %{
          id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
          email: "admin@wraftdocs.com"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end
end
