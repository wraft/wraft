defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.User}
  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      UserLoginRequest:
        swagger_schema do
          title("User Login")
          description("A user log in to the application")

          properties do
            email(:string, "User's email", required: true)
            password(:string, "User's password", required: true)
          end

          example(%{
            email: "email@xyz.com",
            password: "Password"
          })
        end,
      User:
        swagger_schema do
          title("User")
          description("A user of the application")

          properties do
            id(:string, "The ID of the user", required: true)
            name(:string, "Users name", required: true)
            email(:string, "Users email", required: true)
            email_verify(:boolean, "Email verification status")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "John Doe",
            email: "email@xyz.com",
            email_verify: true,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      UserToken:
        swagger_schema do
          title("User and token")
          description("User details with the generated JWT token for authentication")

          properties do
            token(:string, "JWT token for authenticating the user", required: true)
            user(Schema.ref(:User))
          end

          example(%{
            token: "Asdlkqweb.Khgqiwue132.xcli123",
            user: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      CurrentUser:
        swagger_schema do
          title("Current User")
          description("Currently loged in user")

          properties do
            id(:string, "The ID of the user", required: true)
            name(:string, "Users name", required: true)
            email(:string, "Users email", required: true)
            email_verify(:boolean, "Email verification status")
            organisation_id(:integer, "ID of the user's oranisation")
            profile_pic(:string, "User's profile pic URL")
            role(:string, "User's role")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "John Doe",
            email: "email@xyz.com",
            email_verify: true,
            role: "user",
            profile_pic: "www.aws.com/users/johndoe.jpg",
            organisation_id: "jn14786914qklnqw",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ActivityStream:
        swagger_schema do
          title("Activity Stream")
          description("Activity stream object")

          properties do
            action(:string, "Activity action")
            object(:string, "Activity Object")
            meta(:map, "Meta of the activity")
            inserted_at(:string, "When was the user last updated", format: "ISO-8601")
            actor(:string, "Actor name")
            object_details(:map, "Name and ID of the object")
          end
        end,
      ActivityStreamIndex:
        swagger_schema do
          title("Activity Stream")
          description("Activity stream index")

          properties do
            content_types(Schema.ref(:ContentTypesAndLayoutsAndFlows))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example([
            %{
              action: "create",
              object: "Layout:1",
              meta: %{from: "", to: %{name: "Layout 1"}},
              inserted_at: "2020-01-21T14:00:00Z",
              actor: "John Doe",
              object_details: %{name: "Layout 1", id: "jhg1348561234nkjqwd89"}
            }
          ])
        end,
      Error:
        swagger_schema do
          title("Errors")
          description("Error responses from the API")

          properties do
            error(:string, "The message of the error raised", required: true)
          end
        end
    }
  end

  @doc """
  User Login.
  """
  swagger_path :signin do
    post("/users/signin")
    summary("User sign in")
    description("User sign in API")

    parameters do
      user(:body, Schema.ref(:UserLoginRequest), "User to trying to login", required: true)
    end

    response(200, "Ok", Schema.ref(:UserToken))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def signin(conn, params) do
    with %User{} = user <- Account.find(params["email"]),
         {:ok, token, _claims} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      conn
      |> render("sign-in.json", token: token, user: user)
    end
  end

  @doc """
  Current user details.
  """
  swagger_path :me do
    get("/users/me")
    summary("Current user")
    description("Current User details")

    response(200, "Ok", Schema.ref(:CurrentUser))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec me(Plug.Conn.t(), map) :: Plug.Conn.t()
  def me(conn, _params) do
    current_user = conn.assigns[:current_user]
    conn |> render("me.json", user: current_user)
  end

  @doc """
  Activity stream index.
  """
  swagger_path :activity do
    get("/activities")
    summary("Activity stream index")

    description(
      "API to get the list of all activities for which the current user is one of the audience"
    )

    parameter(:page, :query, :string, "Page number")
    response(200, "Ok", Schema.ref(:ContentTypesIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec activity(Plug.Conn.t(), map) :: Plug.Conn.t()
  def activity(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: activities,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Account.get_activity_stream(current_user, params),
         activities <- Account.get_activity_datas(activities) do
      conn
      |> render("activities.json",
        activities: activities,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
