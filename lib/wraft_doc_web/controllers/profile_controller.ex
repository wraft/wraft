defmodule WraftDocWeb.Api.V1.ProfileController do
  use WraftDocWeb, :controller
  plug(WraftDocWeb.Plug.Authorized)
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.Profile}
  action_fallback(WraftDocWeb.FallbackController)

  use PhoenixSwagger

  def swagger_definitions do
    %{
      UserForProfile:
        swagger_schema do
          title("User")
          description("User login details")

          properties do
            id(:string, "User id")
            email(:string, "Email id")
          end

          example(%{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            email: "admin@wraftdocs.com"
          })
        end,
      ProfileRequest:
        swagger_schema do
          title("Profile Request")
          description("User profile details to create")

          properties do
            name(:string, "Name of the user", required: true)
            dob(:date, "Date of birth")
            profile_pic(:string, "path to profile pic")
            gender(:string, "Users gender")
          end

          example(%{
            name: "Jhone",
            dob: "1992-09-24",
            gender: "Male",
            profile_pic: "/image.png"
          })
        end,
      Profile:
        swagger_schema do
          title("Profile")
          description("Profile details")

          properties do
            name(:string, "Name of the user", required: true)
            dob(:date, "Date of birth")
            gender(:string, "Users gender")
            profile_pic(:string, "path to profile pic")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
            user(Schema.ref(:UserForProfile))
          end

          example(%{
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
          })
        end
    }
  end

  # Profile Update
  swagger_path :update do
    put("/profiles")
    summary("update users profile")
    description("Update users profile")
    operation_id("update_profile")
    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Name", required: true)
    parameter(:profile_pic, :formData, :file, "Profile pic")
    parameter(:dob, :formData, :date, "Date of Birth")
    parameter(:gender, :formData, :string, "Gender", required: true)

    response(200, "Updated", Schema.ref(:Profile))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def update(conn, params) do
    with %Profile{} = profile <- Account.update_profile(conn, params) do
      conn
      |> render("profile.json", profile: profile)
    end
  end

  # swagger_path :show do
  #   get("/profiles/{id}")
  #   summary("Show profile details")
  #   description("Show profile details by id")
  #   operation_id("show_profile")

  #   parameters do
  #     id(:path, :string, "Users id", required: true)
  #   end

  #   response(200, "OK", Schema.ref(:Profile))
  #   response(422, "Unprocessable Entity", Schema.ref(:Error))
  #   response(401, "Unauthorized", Schema.ref(:Error))
  # end

  # def show(conn, %{"id" => uuid}) do
  #   with %Profile{} = profile <- Account.get_profile(uuid) do
  #     conn
  #     |> render("profile.json", profile: profile)
  #   end
  # end

  swagger_path :show_current_profile do
    get("/profiles")
    summary("Show current profile")
    description("Api to show current profile")
    operation_id("show_current_profile")
    response(200, "OK", Schema.ref(:Profile))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def show_current_profile(conn, _params) do
    with %Profile{} = profile <- Account.get_current_profile(conn) do
      conn
      |> render("profile.json", profile: profile)
    end
  end
end
