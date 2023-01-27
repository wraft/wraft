defmodule WraftDocWeb.Api.V1.EngineControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  test "index lists engines from database", %{conn: conn} do
    e1 = insert(:engine)
    e2 = insert(:engine)

    conn = get(conn, Routes.v1_engine_path(conn, :index))
    engine_index = json_response(conn, 200)["engines"]
    engine = Enum.map(engine_index, fn %{"name" => name} -> name end)
    assert List.to_string(engine) =~ e1.name
    assert List.to_string(engine) =~ e2.name
  end
end
