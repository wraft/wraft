defmodule WraftDoc.AuthenticationTestsMacro do
  @moduledoc """
  AuthenticationTestsMacro is a macro to minimize duplicate test code
  and follow up DRY principles
  TODO: still yet to implement code

  Ref: https://dev.to/martinthenth/deduplicating-authentication-and-authorization-tests-in-elixir-and-phoenix-using-macros-5c2c?signin=true
  """
  import ExUnit.Assertions

  defmacro test_user_authentication(:path, path) do
    quote generated: true do
      @path unquote(path)
      test "user is not authenticated, render error", %{conn: conn} do
        assert conn
               |> post(path)
               |> json_response(401)
      end

      # test "user is banned, render error", %{conn: conn} do
      #   import WraftDoc.UsersFixtures
      #   import WraftDocWeb.Plug.Authorized

      #   alias WraftDoc.Account.User

      #   user = user_fixture()
      #   token = session_fixture()
      #   User.ban_user(user, true)

      #   assert conn
      #          |> put_req_header("authorization", token)
      #          |> post(path)
      #          |> json_response(401)
      #   end
    end
  end
end
