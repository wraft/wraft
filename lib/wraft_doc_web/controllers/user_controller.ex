defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.AddActionLog)
  import Ecto.Query, warn: false

  require Logger

  alias WraftDoc.Account
  alias WraftDoc.Account.AuthToken
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise
  alias WraftDocWeb.Guardian

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
            email: "wraftuser@gmail.com",
            password: "password"
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
      LoggedInUser:
        swagger_schema do
          title("Logged in user")
          description("A user of the application who just logged in or registered")

          properties do
            id(:string, "The ID of the user", required: true)
            name(:string, "Users name", required: true)
            email(:string, "Users email", required: true)
            email_verify(:boolean, "Email verification status")
            profile_pic(:string, "URL of the user's profile picture")
            organisation_id(:string, "User's current organisation ID", required: true)
            roles(:array, "Roles of the user", required: true)
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "John Doe",
            email: "email@xyz.com",
            email_verify: true,
            profile_pic: "www.minio.com/users/johndoe.jpg",
            organisation_id: "466f1fa1-9657-4166-b372-21e8135aeaf1",
            roles: [%{id: "756f1fa1-9657-4166-b372-21e8135aeaf1", name: "superadmin"}],
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      UserToken:
        swagger_schema do
          title("User and token")
          description("User details with the generated JWT token for authentication")

          properties do
            access_token(:string, "JWT access token for authenticating the user", required: true)

            refresh_token(:string, "JWT refresh token for refreshing access token", required: true)

            user(Schema.ref(:LoggedInUser))
          end

          example(%{
            access_token: "Asdlkqweb.Khgqiwue132.xcli123",
            refresh_token: "Asdlkqweb.Khgqiwue132.xcli123",
            user: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              profile_pic: "www.minio.com/users/johndoe.jpg",
              organisation_id: "466f1fa1-9657-4166-b372-21e8135aeaf1",
              roles: [%{id: "756f1fa1-9657-4166-b372-21e8135aeaf1", name: "superadmin"}],
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
            info(:string, "Response Info")
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
            info(:string, "Info")
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
        end,
      EmailTokenVerifiedInfo:
        swagger_schema do
          title("Email Token verified info")
          description("Email Token verified info")

          properties do
            info(:string, "Info")
            verification_status(:boolean, true)
          end
        end,
      ResendEmailTokenRequest:
        swagger_schema do
          title("Resend Email Token")
          description("Resend token for account verification")

          properties do
            token(:string, "Token is given in email", required: true)
          end

          example(%{
            token:
              "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
          })
        end,
      OrganisationByUser:
        swagger_schema do
          title("Organisation by user")
          description("Organisation spec for a given user")

          properties do
            id(:string, "id of the organisation")
            name(:string, "name of the organisation")
            logo(:string, "logo of the organisation")
          end
        end,
      OrganisationByUserIndex:
        swagger_schema do
          title("Organisation by user index")
          description("List Organisations by a user")

          properties do
            organisations(Schema.ref(:OrganisationByUser))
          end

          example(%{
            organisations: [
              %{
                id: "5c69ce59-5b38-4a63-ab34-17b29d157887",
                name: "Invited org",
                logo: "/logo.jpg"
              },
              %{
                id: "25af23bc-47b4-4560-a1b1-e41b31020733",
                name: "Personal",
                logo: "/logo_personal.jpg"
              }
            ]
          })
        end,
      RefreshTokenRequest:
        swagger_schema do
          title("Refresh Token")
          description("Refresh Token to get new pair of tokens")

          properties do
            token(:string, "Refresh Token", required: true)
          end

          example(%{
            token:
              "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
          })
        end,
      RefreshToken:
        swagger_schema do
          title("Refresh Token")
          description("New pair of access token and refresh token")

          properties do
            access_token(:string, "Access Token")
            refresh_token(:string, "Refresh Token")
          end

          example(%{
            access_token:
              "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf",
            refresh_token:
              "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
          })
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
         %{user: user, tokens: [access_token: access_token, refresh_token: refresh_token]} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      render(conn, "sign-in.json",
        access_token: access_token,
        refresh_token: refresh_token,
        user: user
      )
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
    current_user = conn.assigns.current_user
    render(conn, "me.json", %{user: current_user})
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
    with %AuthToken{} = auth_token <- Account.create_password_token(params) do
      Account.send_password_reset_mail(auth_token)

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{info: "Success"}))
    end
  end

  @doc """
  Verify password reset link/token.
  """
  swagger_path :verify_token do
    get("/user/password/reset/{token}")
    summary("Verify password")
    description("Verify password reset link")

    parameters do
      token(:path, :string, "Token", requried: true)
    end

    response(200, "Ok", Schema.ref(:TokenVerifiedInfo))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec verify_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_token(conn, %{"token" => token}) do
    with %AuthToken{} = auth_token <- Account.check_token(token, :password_verify) do
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
      token(:body, Schema.ref(:ResetPasswordRequest), "Password details to reset", required: true)
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

  @doc """
    Resend email token from expired token sent to mail
  """
  swagger_path :resend_email_token do
    post("/user/resend_email_token")
    summary("Resend email token")
    description("Api to resend the email token especially if the token is expired")

    parameters do
      token(:body, Schema.ref(:ResendEmailTokenRequest), "Token", required: true)
    end

    response(200, "ok", Schema.ref(:TokenVerifiedInfo))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec resend_email_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def resend_email_token(conn, %{"token" => token}) do
    with %AuthToken{} = auth_token <- Account.get_auth_token(token, :email_verify),
         %User{} = user <- Account.get_user(auth_token.user_id),
         {:ok, %Oban.Job{}} <- Account.create_token_and_send_email(user.email) do
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{info: "Success"}))
    end
  end

  @doc """
    Verify email token using token sent to mail
  """
  swagger_path :verify_email_token do
    get("/user/verify_email_token/{token}")
    summary("Verify email token")
    description("Api to verify whether the user email to validate the account")

    parameters do
      token(:path, :string, "Token", required: true)
    end

    response(200, "ok", Schema.ref(:EmailTokenVerifiedInfo))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec verify_email_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_email_token(conn, %{"token" => token}) do
    with {:ok, %{email: email}} <- Account.check_token(token, :email_verify),
         %User{} = user <- Account.get_user_by_email(email),
         {:ok, %User{email_verify: true} = user} <- Account.update_email_status(user) do
      render(conn, "check_email_token.json", verification_status: user.email_verify)
    end
  end

  @doc """
    List Organisations by user
  """
  swagger_path :index_by_user do
    get("/users/organisations")
    summary("List organisations by user")
    description("List of all the organsiations the user is part of")

    response(200, "Ok", Schema.ref(:OrganisationByUserIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index_by_user(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index_by_user(conn, _params) do
    current_user = conn.assigns.current_user

    with %User{} = user <- Enterprise.list_org_by_user(current_user) do
      render(conn, "index_by_user.json", organisations: user.organisations)
    end
  end

  @doc """
    Switch Organisation of the user.
  """
  swagger_path :switch_organisation do
    post("/switch_organisations")
    summary("Switch organisation of the user")
    description("Switch the current organisation of the user to another one")
    consumes("multipart/form-data")

    parameter(:organisation_id, :formData, :string, "Organisation id", required: true)

    response(200, "Ok", Schema.ref(:UserToken))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def switch_organisation(conn, %{"organisation_id" => organisation_id}) do
    current_user = conn.assigns[:current_user]

    with %User{} = user <- Enterprise.list_org_by_user(current_user),
         true <- Enum.any?(user.organisations, &(&1.id == organisation_id)),
         user <- Enterprise.get_roles_by_organisation(user, organisation_id) do
      tokens = Guardian.generate_tokens(current_user, organisation_id)

      render(conn, "sign-in.json",
        access_token: Keyword.get(tokens, :access_token),
        refresh_token: Keyword.get(tokens, :refresh_token),
        user: Map.put(user, :current_org_id, organisation_id)
      )
    else
      false ->
        {:error, :no_permission}
    end
  end

  @doc """
    Join an organisation from invite link
  """
  swagger_path :join_organisation do
    post("/join_organisation")
    summary("Join Organisation")
    description("Join organisation using an invite link")
    consumes("multipart/form-data")

    parameter(:token, :formData, :string, "Organisation Invite Token", required: true)

    response(200, "Ok", Schema.ref(:OrganisationByUser))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec join_organisation(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def join_organisation(conn, %{"token" => token} = _params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %{organisations: organisation}} <-
           Enterprise.join_org_by_invite(current_user, token) do
      render(conn, "join_org.json", organisation: organisation)
    end
  end

  @doc """
    New pair of tokens from existing refresh token
  """
  swagger_path :refresh_token do
    post("/users/token_refresh")
    summary("Refresh Token")
    description("Gives a new pair of access token and refresh token")

    parameters do
      token(:body, Schema.ref(:RefreshTokenRequest), "Refresh Token", requried: true)
    end

    response(200, "Ok", Schema.ref(:RefreshToken))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec refresh_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def refresh_token(conn, %{"token" => refresh_token}) do
    case Account.refresh_token_exchange(refresh_token) do
      {:ok, access_token: access_token, refresh_token: refresh_token} ->
        render(conn, "token.json", access_token: access_token, refresh_token: refresh_token)

      {:error, error} ->
        Logger.error("Refresh token creation failed. Invalid input data provided.", error: error)

        conn
        |> put_status(401)
        |> render("token.json", error: error)
    end
  end
end
