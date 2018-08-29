defmodule StarterWeb.Router do
  use StarterWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(StarterWeb.Guardian.AuthPipeline)
  end

  scope "/", StarterWeb do
  # Use the default browser stack
    pipe_through(:api)
    get("/", PageController, :index)
  end

  # Other scopes may use custom stacks.
  scope "/api", StarterWeb do
    pipe_through(:api)

    # auth & user

    scope "/v1", Api.V1, as: :v1 do
      post("/user/register", RegistrationController, :create)
    end
  end
end
