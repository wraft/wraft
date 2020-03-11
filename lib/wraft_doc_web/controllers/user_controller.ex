defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
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
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
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
end
