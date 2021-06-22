defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.AuthToken, Account.User}
  alias WraftDocWeb.{Mailer, Mailer.Email}
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
      UserSearch:
        swagger_schema do
          title("User")
          description("A user of the application")

          properties do
            users(Schema.ref(:User))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            page_number: 1,
            total_entries: 2,
            total_pages: 1,
            users: [
              %{
                email: "admin@wraftdocs.com",
                email_verify: false,
                id: "466f1fa1-9657-4166-b372-21e8135aeaf1",
                inserted_at: "2021-05-06T15:26:52",
                name: "Admin",
                updated_at: "2021-05-06T15:26:52"
              }
            ]
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
            activities(Schema.ref(:ActivityStream))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            activities: [
              %{
                action: "create",
                object: "Layout:1",
                meta: %{from: "", to: %{name: "Layout 1"}},
                inserted_at: "2020-01-21T14:00:00Z",
                actor: "John Doe",
                object_details: %{name: "Layout 1", id: "jhg1348561234nkjqwd89"}
              },
              %{
                action: "delete",
                object: "Layout:1,Layout 1",
                meta: %{},
                inserted_at: "2020-01-21T14:00:00Z",
                actor: "John Doe",
                object_details: %{name: "Layout 1"}
              }
            ],
            page_number: 1,
            total_pages: 10,
            total_entries: 100
          })
        end,
      Error:
        swagger_schema do
          title("Errors")
          description("Error responses from the API")

          properties do
            error(:string, "The message of the error raised", required: true)
          end
        end,
      ResetPasswordRequest:
        swagger_schema do
          title("Reset password request")
          description("Request to reset password")

          properties do
            token(:string, "Token has given in email", required: true)
            password(:string, "New password to update", required: true)
          end

          example(%{
            token:
              "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf",
            password: "new password"
          })
        end,
      AuthToken:
        swagger_schema do
          title("Auth token")
          description("Response for reset password request")

          properties do
            info(:string, "Response info")
          end

          example(%{
            info: "A password reset link has been sent to your email.!"
          })
        end,
      TokenVerifiedInfo:
        swagger_schema do
          title("Token verified info")
          description("Token verified info")

          properties do
            info(:string, "info")
          end
        end,
      UpdatePasswordRequest:
        swagger_schema do
          title("Password to update")
          description("Request to update password")

          properties do
            current_password(:string, "Current password", required: true)
            password(:string, "Password to update", required: true)
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

  @spec signin(Plug.Conn.t(), map) :: Plug.Conn.t()
  def signin(conn, params) do
    with %User{} = user <- Account.find(params["email"]),
         {:ok, token, _claims} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      render(conn, "sign-in.json", token: token, user: user)
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
    render(conn, "me.json", user: conn.assigns[:current_user])
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
    response(200, "Ok", Schema.ref(:ActivityStreamIndex))
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
         } <- Account.get_activity_stream(current_user, params) do
      render(conn, "activities.json",
        activities: activities,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Generate auth token for password reset for the user with the given email ID.
  """
  swagger_path :generate_token do
    post("/user/password/forgot")
    summary("Generate token")
    description("Api to generate token to update password")

    parameters do
      email(:body, :string, "Email", required: true)
    end

    response(200, "Ok", Schema.ref(:AuthToken))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec generate_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def generate_token(conn, params) do
    with %AuthToken{} = auth_token <- Account.create_token(params) do
      auth_token |> Email.password_reset() |> Mailer.deliver_now()

      render(conn, "auth_token.json", auth_token: auth_token)
    end
  end

  @doc """
  Verify password reset link/token.
  """
  swagger_path :verify_token do
    get("/user/password/reset/{token}")
    summary("Veriy password")
    description("Verify password reset link")

    parameters do
      token(:path, :string, "Token", requried: true)
    end

    response(200, "Ok", Schema.ref(:TokenVerifiedInfo))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec verify_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_token(conn, %{"token" => token}) do
    with %AuthToken{} = auth_token <- Account.check_token(token) do
      render(conn, "check_token.json", token: auth_token.value)
    end
  end

  @doc """
  Reset the forgotten password.
  """
  swagger_path :reset do
    post("/user/password/reset")
    summary("Reset password")
    description("Reseting password of user")

    parameters do
      token(:body, Schema.ref(:ResetPasswordRequest), "Password deteails to reset", required: true)
    end

    response(200, "Ok", Schema.ref(:User))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec reset(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset(conn, params) do
    with %User{} = user <- Account.reset_password(params) do
      render(conn, "user.json", user: user)
    end
  end

  @doc """
  Update the password.
  """
  swagger_path :update_password do
    post("/users/password")
    summary("Update password")
    description("Authenticated updation of password")

    parameters do
      password(:body, Schema.ref(:UpdatePasswordRequest), "Password to update", required: true)
    end

    response(201, "Accepted", Schema.ref(:User))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update_password(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_password(conn, params) do
    current_user = conn.assigns.current_user

    with %User{} = user <- Account.update_password(current_user, params) do
      render(conn, "user.json", user: user)
    end
  end

  @doc """
  Search a user by there name
  """

  swagger_path :search do
    get("/users/search")
    summary("Search User")
    description("Filtered user by there name")

    parameters do
      key(:query, :string, "Search key")
      page(:query, :string, "Page number")
    end

    response(200, "ok", Schema.ref(:UserSearch))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def search(conn, %{"key" => key} = params) do
    with %{
           entries: users,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Account.get_user_by_name(key, params) do
      render(conn, "index.json",
        users: users,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :remove do
    post("users/remove")
    summary("Api to remove a user")
    description("Api to remove a user from an organisation")

    parameters do
      id(:path, :string, "User id")
    end

    response(200, "ok", Schema.ref(:User))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def remove(conn, %{"id" => user_id}) do
    with %User{} = user <- Account.remove_user(conn.assigns.current_user, user_id) do
      render(conn, "remove.json", user: user)
    end
  end
end
