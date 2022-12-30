defmodule WraftDocWeb.Plug.VerifiedEmailCheckTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDocWeb.Plug.VerifiedEmailCheck

  test "user is allowed to continue if the email is already verified" do
    user = insert(:user, email_verify: true)

    conn = assign(build_conn(), :current_user, user)
    returned_conn = VerifiedEmailCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "returns 400 when user's email is not verified" do
    user = insert(:user)

    conn = assign(build_conn(), :current_user, user)
    returned_conn = VerifiedEmailCheck.call(conn, %{})

    assert returned_conn.status == 400

    assert json_response(returned_conn, 400)["errors"] ==
             "Your email is not verified. Please request a new email verification link.!"
  end
end
