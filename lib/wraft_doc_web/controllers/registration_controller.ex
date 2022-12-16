defmodule WraftDocWeb.Api.V1.RegistrationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  import Ecto.Query, warn: false
  alias WraftDoc.Account
  alias WraftDoc.Account.User

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
    tag("Registration")

    parameters do
      token(:query, :string, "Token obtained from invitation mail")
      user(:body, Schema.ref(:UserRegisterRequest), "User to register", required: true)
    end

    response(200, "Ok", Schema.ref(:UserToken))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with {:ok, %{organisations: organisations, user: %User{} = user}} <-
           Account.registration(params),
         {:ok, token, _claims} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      conn
      |> put_status(:created)
      |> render("create.json", user: user, token: token, organisations: organisations)
    end
  end
end
