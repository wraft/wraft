defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug(WraftDocWeb.Plug.AddActionLog)
  import Ecto.Query, warn: false

  require Logger

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Enterprise
  alias WraftDoc.FeatureFlags
  alias WraftDoc.Notifications.Delivery
  alias WraftDocWeb.Guardian
  alias WraftDocWeb.Schemas

  action_fallback(WraftDocWeb.FallbackController)

  tags(["User"])

  @doc """
  User Login.
  """
  operation(:signin,
    summary: "User sign in",
    description: "User sign in API",
    request_body: {"User to trying to login", "application/json", Schemas.User.UserLoginRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.UserToken},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

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
  User Login with Google.
  """
  operation(:signin_with_google,
    summary: "User sign in with google",
    description: "User sign in with google API",
    request_body:
      {"User to trying to login", "application/json", Schemas.User.UserGoogleLoginRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.UserToken},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  # TODO Add controller tests
  @spec signin(Plug.Conn.t(), map) :: Plug.Conn.t()
  def signin_with_google(conn, %{"token" => token} = _params) do
    with {:ok, %{email: email}} <- AuthTokens.google_auth_validation(token),
         %User{} = user <- Account.find(email),
         {:ok, %User{email_verify: true} = user} <- Account.update_email_status(user),
         %{organisation: _personal_org, user: user} <-
           Enterprise.get_personal_organisation_and_role(user),
         [access_token: access_token, refresh_token: refresh_token] <-
           Guardian.generate_tokens(user, user.last_signed_in_org_id) do
      render(conn, "sign-in.json",
        access_token: access_token,
        refresh_token: refresh_token,
        user: user
      )
    end
  end

  @doc """
  Check Email.
  """
  operation(:check_email,
    summary: "Check Email",
    description: "Check Email",
    parameters: [
      email: [in: :query, type: :string, description: "Email", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.User.CheckEmailRequest},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  # TODO write test
  @spec check_email(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check_email(conn, %{"email" => email}) do
    case Account.find(email) do
      %User{} = _user ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, Jason.encode!(%{info: "Email Exist!"}))

      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(404, Jason.encode!(%{error: "Email does not exist!"}))
    end
  end

  @doc """
  Current user details.
  """
  operation(:me,
    summary: "Current user",
    description: "Current User details",
    responses: [
      ok: {"Ok", "application/json", Schemas.User.CurrentUser},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec me(Plug.Conn.t(), map) :: Plug.Conn.t()
  def me(conn, _params) do
    current_user = conn.assigns.current_user

    features =
      current_user.current_org_id
      |> Enterprise.get_organisation()
      |> FeatureFlags.get_organization_features()

    render(conn, "me.json", %{user: current_user, features: features})
  end

  @doc """
  Activity stream index.
  """
  operation(:activity,
    summary: "Activity stream index",
    description:
      "API to get the list of all activities for which the current user is one of the audience",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.User.ActivityStreamIndex},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

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
  operation(:generate_token,
    summary: "Generate token",
    description: "Api to generate token to update password",
    request_body:
      {"Details to generate token", "application/json",
       Schemas.User.GeneratePasswordSetTokenRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.AuthToken},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec generate_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  # TODO - Update tests to check correct mail is send
  def generate_token(conn, params) do
    with %AuthToken{} = auth_token <- AuthTokens.create_password_token(params) do
      if params["first_time_setup"] do
        Account.send_password_set_mail(auth_token)
      else
        Account.send_password_reset_mail(auth_token)
      end

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{info: "Success"}))
    end
  end

  @doc """
  Verify password reset link/token.
  """
  operation(:verify_token,
    summary: "Verify password",
    description: "Verify password reset link",
    parameters: [
      token: [in: :path, type: :string, description: "Token", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.User.TokenVerifiedInfo},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec verify_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_token(conn, %{"token" => token}) do
    with %AuthToken{} = auth_token <- AuthTokens.check_token(token, :password_verify) do
      render(conn, "check_token.json", token: auth_token.value)
    end
  end

  @doc """
  Reset the forgotten password.
  """
  operation(:reset,
    summary: "Reset password",
    description: "Reseting password of user",
    request_body:
      {"Password details to reset", "application/json", Schemas.User.ResetPasswordRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.User},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec reset(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset(conn, params) do
    with %User{} = user <- Account.reset_password(params) do
      render(conn, "user.json", user: user)
    end
  end

  @doc """
  Update the password.
  """
  operation(:update_password,
    summary: "Update password",
    description: "Authenticated updation of password",
    request_body: {"Password to update", "application/json", Schemas.User.UpdatePasswordRequest},
    responses: [
      created: {"Accepted", "application/json", Schemas.User.User},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

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
  operation(:search,
    summary: "Search User",
    description: "Filtered user by there name",
    parameters: [
      key: [in: :query, type: :string, description: "Search key"],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"ok", "application/json", Schemas.User.UserSearch},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  # TODO add tests
  def search(conn, %{"key" => _key} = params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: users,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Account.get_user_by_name(current_user, params) do
      render(conn, "index.json",
        users: users,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:remove,
    summary: "Api to remove a user",
    description: "Api to remove a user from an organisation",
    parameters: [
      id: [in: :path, type: :string, description: "User id"]
    ],
    responses: [
      ok: {"ok", "application/json", Schemas.User.User},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def remove(conn, %{"id" => user_id}) do
    with %User{} = user <- Account.remove_user(conn.assigns.current_user, user_id) do
      render(conn, "remove.json", user: user)
    end
  end

  @doc """
    Resend email token from expired token sent to mail
  """
  operation(:resend_email_token,
    summary: "Resend email token",
    description: "Api to resend the email token especially if the token is expired",
    request_body: {"Token", "application/json", Schemas.User.ResendEmailTokenRequest},
    responses: [
      ok: {"ok", "application/json", Schemas.User.TokenVerifiedInfo},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec resend_email_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def resend_email_token(conn, %{"token" => token}) do
    with %AuthToken{} = auth_token <- AuthTokens.get_auth_token(token, :email_verify),
         %User{} = user <- Account.get_user(auth_token.user_id),
         {:ok, %Oban.Job{}} <- AuthTokens.create_token_and_send_email(user.email) do
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{info: "Success"}))
    end
  end

  @doc """
    Verify email token using token sent to mail
  """
  operation(:verify_email_token,
    summary: "Verify email token",
    description: "Api to verify whether the user email to validate the account",
    parameters: [
      token: [in: :path, type: :string, description: "Token", required: true]
    ],
    responses: [
      ok: {"ok", "application/json", Schemas.User.EmailTokenVerifiedInfo},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec verify_email_token(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_email_token(conn, %{"token" => token}) do
    with {:ok, %{email: email}} <- AuthTokens.check_token(token, :email_verify),
         %User{} = user <- Account.get_user_by_email(email),
         {:ok, %User{email_verify: true} = user} <- Account.update_email_status(user) do
      render(conn, "check_email_token.json", verification_status: user.email_verify)
    end
  end

  @doc """
    List Organisations by user
  """
  operation(:index_by_user,
    summary: "List organisations by user",
    description: "List of all the organsiations the user is part of",
    responses: [
      ok: {"Ok", "application/json", Schemas.User.OrganisationByUserIndex},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec index_by_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index_by_user(conn, _params) do
    current_user = conn.assigns.current_user

    with %User{} = user <- Enterprise.list_org_by_user(current_user) do
      render(conn, "index_by_user.json", organisations: user.organisations)
    end
  end

  @doc """
    Switch Organisation of the user.
  """
  operation(:switch_organisation,
    summary: "Switch organisation of the user",
    description: "Switch the current organisation of the user to another one",
    request_body:
      {"Organisation id", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{organisation_id: %OpenApiSpex.Schema{type: :string}}
       }},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.UserToken},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def switch_organisation(conn, %{"organisation_id" => organisation_id}) do
    current_user = conn.assigns[:current_user]

    with %User{} = user <- Enterprise.list_org_by_user(current_user),
         true <- Enum.any?(user.organisations, &(&1.id == organisation_id)),
         user <- Enterprise.get_roles_by_organisation(user, organisation_id) do
      tokens = Guardian.generate_tokens(current_user, organisation_id)
      Account.update_last_signed_in_org(user, organisation_id)

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
  operation(:join_organisation,
    summary: "Join Organisation",
    description: "Join organisation using an invite link",
    request_body:
      {"Organisation Invite Token", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{token: %OpenApiSpex.Schema{type: :string}}
       }},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.OrganisationByUser},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec join_organisation(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def join_organisation(conn, %{"token" => token} = _params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %{organisations: %{id: organisation_id, name: organisation_name} = organisation}} <-
           Enterprise.join_org_by_invite(current_user, token) do
      Task.start(fn ->
        Delivery.dispatch(current_user, "organisation.join_organisation", %{
          organisation_name: organisation_name,
          channel: :user_notification,
          channel_id: current_user.id,
          metadata: %{
            user_id: current_user.id,
            type: "join"
          }
        })
      end)

      Task.start(fn ->
        Delivery.dispatch(current_user, "organisation.join_organisation.all", %{
          user_name: current_user.name,
          channel: :organisation_notification,
          channel_id: organisation_id,
          metadata: %{
            user_id: current_user.id,
            type: "join"
          }
        })
      end)

      render(conn, "join_org.json", organisation: organisation)
    end
  end

  @doc """
    New pair of tokens from existing refresh token
  """
  operation(:refresh_token,
    summary: "Refresh Token",
    description: "Gives a new pair of access token and refresh token",
    request_body: {"Refresh Token", "application/json", Schemas.User.RefreshTokenRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.RefreshToken},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec refresh_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def refresh_token(conn, %{"token" => refresh_token}) do
    case Account.refresh_token_exchange(refresh_token) do
      {:ok, access_token: access_token, refresh_token: refresh_token} ->
        render(conn, "token.json", access_token: access_token, refresh_token: refresh_token)

      {:error, error} ->
        conn
        |> put_status(401)
        |> render("token.json", error: error)
    end
  end

  @doc """
    Set Password of the user.
  """
  operation(:set_password,
    summary: "Set password of the user",
    description: "Set password of the user",
    request_body:
      {"Password details to set", "application/json", Schemas.User.SetPasswordRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.User.SetPasswordResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec set_password(Plug.Conn.t(), map) :: Plug.Conn.t()
  def set_password(conn, %{"token" => token} = params) do
    with {:ok, email} <- AuthTokens.check_token(token, :set_password),
         %User{} = user <- Account.set_password(email, params),
         {:ok, %User{email_verify: true} = _user} <- Account.update_email_status(user) do
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{info: "Success"}))
    end
  end
end
