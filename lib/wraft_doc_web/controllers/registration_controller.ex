defmodule WraftDocWeb.Api.V1.RegistrationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  import Ecto.Query, warn: false

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.Notifications

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      UserRegisterRequest:
        swagger_schema do
          title("Register User")
          description("A user to be registered in the application")

          properties do
            name(:string, "User's name", required: true)
            email(:string, "User's email", required: true)
            password(:string, "User's password", required: true)
            token(:string, "Organisation invite token")
          end

          example(%{
            name: "John Doe",
            email: "email@xyz.com",
            password: "Password"
          })

          example(%{
            name: "John Doe",
            email: "email@xyz.com",
            password: "Password",
            token:
              "U0ZNeU5UWS5nMmdEZEFBQUFBSmtBQVZsYldGcGJHMEFBQUFWYldGMGFHbHNaR0V4TWpoQVoyMWhhV3d1WTI5dFpBQUhkWE5sY2w5cFpHMEFBQUFrTTJFNU1tSTBOMlF0TnpnNU1pMDBaR1kxTFRneU1HWXRZek0xTWpWak9XWTJPRE5sYmdZQXNzTGJESVVCWWdBQlVZQS5DLTEzMVN5YkJmLVJvdHlWcElESXNFOVlPajFMSE9sZXNNOEk1eTVFam1B"
          })
        end
    }
  end

  @doc """
    New registration.
  """
  swagger_path :create do
    post("/users/signup/")
    summary("User registration")
    description("User registration API")
    operation_id("create_user")
    consumes("multipart/form-data")
    tag("Registration")

    parameters do
      token(:query, :string, "Token obtained from invitation mail")
      name(:formData, :string, "User's name", required: true)
      email(:formData, :string, "User's email", required: true)
      password(:formData, :string, "User's password", required: true)
      profile_pic(:formData, :file, "Profile pic")
    end

    response(200, "Ok", Schema.ref(:UserToken))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized for Access", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    case FunWithFlags.enabled?(:waiting_list_registration_control, for: %{email: params["email"]}) do
      true ->
        with {:ok, %{organisations: organisations, user: %User{id: user_id} = user}} <-
               Account.registration(params),
             %{user: user, tokens: [access_token: access_token, refresh_token: refresh_token]} <-
               Account.authenticate(%{user: user, password: params["password"]}) do
          AuthTokens.create_token_and_send_email(params["email"])

          Task.start(fn ->
            Notifications.create_notification([user_id], %{
              type: :user_joins_wraft,
              user_name: user.name
            })
          end)

          conn
          |> put_status(:created)
          |> render("create.json",
            user: user,
            access_token: access_token,
            refresh_token: refresh_token,
            organisations: organisations
          )
        end

      false ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(401, Jason.encode!("Given email is not approved!"))
    end
  end
end
