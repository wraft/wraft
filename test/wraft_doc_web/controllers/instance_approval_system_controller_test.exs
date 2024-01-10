defmodule WraftDocWeb.Api.V1.InstanceApprovalSystemControllerTest do
  @moduledoc """
  Test module for instance approval system controller
  """

  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  describe "index/2" do
    test "lists all documents to approve for an user by user id", %{conn: conn} do
      current_user = conn.assigns.current_user
      as = insert(:approval_system, approver: current_user)
      insert(:instance_approval_system, approval_system: as)

      conn = get(conn, Routes.v1_instance_approval_system_path(conn, :index, current_user.id))

      assert List.first(json_response(conn, 200)["instance_approval_systems"])["approval_system"][
               "id"
             ] == as.id
    end
  end

  describe "instances_to_approve" do
    test "lists all documents to approve for an user by current  user", %{conn: conn} do
      current_user = conn.assigns.current_user
      as = insert(:approval_system, approver: current_user)
      insert(:instance_approval_system, approval_system: as)

      conn = get(conn, Routes.v1_instance_approval_system_path(conn, :instances_to_approve))

      assert List.first(json_response(conn, 200)["instance_approval_systems"])["approval_system"][
               "id"
             ] == as.id
    end
  end
end
