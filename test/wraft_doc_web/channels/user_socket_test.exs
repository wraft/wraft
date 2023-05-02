defmodule WraftDocWeb.UserSocketTest do
  @moduledoc """
  Test for user socket
  """
  use WraftDocWeb.ChannelCase

  import WraftDoc.Factory

  alias WraftDocWeb.Guardian
  alias WraftDocWeb.UserSocket

  test "fail to authenticate without token" do
    assert :error = connect(UserSocket, %{})
  end

  test "fail to authenticate with invalid token" do
    assert :error = connect(UserSocket, %{"token" => "abcdef"})
  end

  test "authenticate and assign user ID with valid token" do
    {:ok, user} = insert(:user)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.current_user.id == user.id
  end
end
