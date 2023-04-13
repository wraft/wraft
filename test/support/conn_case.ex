defmodule WraftDocWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use WraftDocWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WraftDocWeb.ConnCase
      alias WraftDocWeb.Router.Helpers, as: Routes
      import Bureaucrat.Helpers
      import WraftDoc.Factory

      # The default endpoint for testing
      @endpoint WraftDocWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WraftDoc.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    user = WraftDoc.Factory.insert(:user_with_organisation)

    WraftDoc.Factory.insert(:user_organisation,
      user: user,
      organisation: List.first(user.owned_organisations)
    )

    user = WraftDoc.Factory.insert(:user_with_organisation)
    organisation = List.first(user.owned_organisations)

    WraftDoc.Factory.insert(:user_organisation,
      user: user,
      organisation: organisation
    )

    role = WraftDoc.Factory.insert(:role, organisation: organisation)
    WraftDoc.Factory.insert(:user_role, user: user, role: role)

    WraftDoc.Factory.insert(:membership, organisation: List.first(user.owned_organisations))

    {:ok, token, _} =
      WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> Plug.Conn.assign(:current_user, user)

    {:ok, conn: conn}
  end
end
