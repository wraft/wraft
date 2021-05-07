defmodule WraftDocWeb.Api.V1.UserControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{Account.AuthToken, Repo}
  alias WraftDocWeb.Endpoint

  setup %{conn: conn} do
    profile = insert(:profile)
    user = Repo.preload(profile.user, [:profile, :role, :organisation])

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  describe "signin/2" do
    test "succesfully logs in with correct email-password combination" do
      user = insert(:user)

      conn = build_conn()

      conn =
        post(
          conn,
          Routes.v1_user_path(conn, :signin, %{
            email: user.email,
            password: user.password
          })
        )

      assert json_response(conn, 200)["user"]["email"] == user.email
      assert json_response(conn, 200)["token"] != nil
    end

    test "returns error with wrong email-password combination" do
      user = insert(:user)
      conn = build_conn()

      conn =
        post(
          conn,
          Routes.v1_user_path(conn, :signin, %{email: user.email, password: "wrong password"})
        )

      assert json_response(conn, 404)["errors"] ==
               "Your email-password combination doesn't match. Please try again.!"
    end

    test "returns error with non-existing email" do
      conn = build_conn()

      conn =
        post(
          conn,
          Routes.v1_user_path(conn, :signin, %{
            email: "non.existing@email.com",
            password: "wrong password"
          })
        )

      assert json_response(conn, 404)["errors"] ==
               "Your email-password combination doesn't match. Please try again.!"
    end

    test "returns error when no password is given" do
      user = insert(:user)
      conn = build_conn()

      conn = post(conn, Routes.v1_user_path(conn, :signin, %{email: user.email}))

      assert json_response(conn, 400)["errors"] == "Please provide all necessary datas to login.!"
    end
  end

  describe "me/2" do
    test "returns the current logined user", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)
      ur = insert(:user_role, user: user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_user_path(conn, :me))
      assert json_response(conn, 200)["email"] == user.email
      # assert json_response(conn, 200)["role"] == user.role.name
      assert json_response(conn, 200)["roles"]
             |> Enum.map(fn x -> x["name"] end)
             |> List.to_string() =~
               ur.role.name

      assert json_response(conn, 200)["profile_pic"] ==
               WraftDocWeb.PropicUploader.url({user.profile.profile_pic, user.profile})
    end
  end

  describe "generate_token/2" do
    test "generates token and renders confirmation message with existing email" do
      user = insert(:user)
      conn = build_conn()

      count_before = AuthToken |> Repo.all() |> length()
      conn = post(conn, Routes.v1_user_path(conn, :generate_token, %{email: user.email}))
      count_after = AuthToken |> Repo.all() |> length()

      assert json_response(conn, 200)["info"] ==
               "A password reset link has been sent to your email.!"

      assert count_before + 1 == count_after
    end

    test "returns error with non-existant email" do
      conn = build_conn()

      count_before = AuthToken |> Repo.all() |> length()

      conn =
        post(conn, Routes.v1_user_path(conn, :generate_token), %{email: "non.existing@email.com"})

      count_after = AuthToken |> Repo.all() |> length()

      assert json_response(conn, 404)["errors"] == "No user with this email.!"

      assert count_before == count_after
    end
  end

  describe "verify_token/2" do
    test "returns Approved with valid token" do
      conn = build_conn()
      user = insert(:user)

      token = Endpoint |> Phoenix.Token.sign("reset", user.email) |> Base.url_encode64()

      insert(:auth_token, value: token, token_type: "password_verify")
      conn = get(conn, Routes.v1_user_path(conn, :verify_token, token))
      assert json_response(conn, 200)["info"] == "Approved"
    end

    test "returns error with invalid token" do
      conn = build_conn()
      insert(:auth_token, value: "_3_-_A==", token_type: "password_verify")
      conn = get(conn, Routes.v1_user_path(conn, :verify_token, "_3_-_A=="))
      assert json_response(conn, 401)["errors"] == "You are not authorized for this action.!"
    end

    test "returns error with expired token" do
      conn = build_conn()
      user = insert(:user)

      token =
        Endpoint
        |> Phoenix.Token.sign("reset", user.email, signed_at: -861)
        |> Base.url_encode64()

      insert(:auth_token, value: token, token_type: "password_verify")
      conn = get(conn, Routes.v1_user_path(conn, :verify_token, token))
      assert json_response(conn, 400)["errors"] == "Expired.!"
    end
  end

  describe "reset/2" do
    test "resets password and deletes the auth token with valid token and attrs" do
      conn = build_conn()
      user = insert(:user)

      token = Endpoint |> Phoenix.Token.sign("reset", user.email) |> Base.url_encode64()

      insert(:auth_token, value: token, token_type: "password_verify", user: user)
      attrs = %{token: token, password: "123456789"}
      before_count = AuthToken |> Repo.all() |> length()
      conn = post(conn, Routes.v1_user_path(conn, :reset, attrs))

      assert before_count - 1 == AuthToken |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == user.name
      assert json_response(conn, 200)["email"] == user.email
      assert json_response(conn, 200)["id"] == user.uuid
    end

    test "does not reset password with valid token and invalid attrs" do
      conn = build_conn()
      user = insert(:user)

      token = Endpoint |> Phoenix.Token.sign("reset", user.email) |> Base.url_encode64()

      insert(:auth_token, value: token, token_type: "password_verify")
      attrs = %{token: token, password: "123"}
      conn = post(conn, Routes.v1_user_path(conn, :reset, attrs))

      assert json_response(conn, 422)["errors"]["password"] == [
               "should be at least 8 character(s)"
             ]
    end

    test "returns not found error when attrs does not contain all required values" do
      conn = build_conn()
      conn = post(conn, Routes.v1_user_path(conn, :reset, %{}))

      assert json_response(conn, 404) == "Not Found"
    end

    test "returns error with invalid token" do
      conn = build_conn()
      insert(:auth_token, value: "_3_-_A==", token_type: "password_verify")

      conn =
        post(conn, Routes.v1_user_path(conn, :reset, %{token: "_3_-_A==", password: "eeqeqe"}))

      assert json_response(conn, 401)["errors"] == "You are not authorized for this action.!"
    end

    test "returns error with expired token" do
      conn = build_conn()
      user = insert(:user)

      token =
        Endpoint
        |> Phoenix.Token.sign("reset", user.email, signed_at: -861)
        |> Base.url_encode64()

      insert(:auth_token, value: token, token_type: "password_verify")
      conn = post(conn, Routes.v1_user_path(conn, :reset, %{token: token, password: "eeqeqe"}))
      assert json_response(conn, 400)["errors"] == "Expired.!"
    end
  end

  describe "update/2" do
    test "updates password with valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      attrs = %{current_password: "encrypt", password: "password"}
      conn = put(conn, Routes.v1_user_path(conn, :update_password, attrs))

      assert json_response(conn, 200)["id"] == user.uuid
      assert json_response(conn, 200)["email"] == user.email
      refute json_response(conn, 200)["updated_at"] == user.updated_at
    end

    test "does not update password with invalid attrs", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      attrs = %{current_password: "encrypt", password: "invalid"}
      conn = put(conn, Routes.v1_user_path(conn, :update_password, attrs))

      assert json_response(conn, 422)["errors"]["password"] == [
               "should be at least 8 character(s)"
             ]
    end

    test "does not update password and returns wrong password error with wrong current password",
         %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      attrs = %{current_password: "wrong password", password: "invalid"}
      conn = put(conn, Routes.v1_user_path(conn, :update_password, attrs))

      assert json_response(conn, 400)["errors"] == "You have entered a wrong password.!"
    end

    test "does not update password and returns same password error when new password is same as old one",
         %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      attrs = %{current_password: "encrypt", password: "encrypt"}
      conn = put(conn, Routes.v1_user_path(conn, :update_password, attrs))

      assert json_response(conn, 400)["errors"] ==
               "Please enter a password that does not match with your current one.!"
    end

    test "returns not found error when attrs does not contain all required values", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = put(conn, Routes.v1_user_path(conn, :update_password, %{}))

      assert json_response(conn, 404) == "Not Found"
    end
  end

  # describe "search/2" do
  #   test "search user api filter by there name", %{conn: conn} do
  #     conn =
  #       build_conn()
  #       |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #       |> assign(:current_user, conn.assigns.current_user)

  #     user = conn.assigns.current_user
  #     insert(:membership, organisation: user.organisation)

  #     user = insert(:user)

  #     conn =
  #       get(
  #         conn,
  #         Routes.v1_user_path(conn, :search), key: "Admin"
  #       )

  #     content_type = json_response(conn, 200)["Admin"]
  #   end
  # end
end
