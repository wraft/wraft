defmodule WraftDocWeb.UserSocketTest do
  @moduledoc """
  Test for user socket
  """
  use WraftDocWeb.ChannelCase
  alias WraftDoc.Account
  alias WraftDocWeb.Guardian
  alias WraftDocWeb.UserSocket

  @params %{
    name: "Functionary",
    email: "functionaryyyy@gmail.com",
    password: "functionary"
  }

  test "fail to authenticate without token" do
    assert :error = connect(UserSocket, %{})
  end

  test "fail to authenticate with invalid token" do
    assert :error = connect(UserSocket, %{"token" => "abcdef"})
  end

  test "authenticate and assign user ID with valid token" do
    {:ok, user} = Account.create_user(@params)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.current_user.id == user.id
  end
end
