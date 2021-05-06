defmodule WraftDoc.SeedGate do
  @moduledoc """
  Module for helpers of seeds
  """
  alias WraftDoc.{Account.User, Repo}

  @doc """
  Seed data once a particular sruct
  """
  def allow_once(data, opts) do
    module = data.__struct__

    case Repo.get_by(module, opts) do
      nil ->
        Repo.insert!(data)

      data ->
        data
    end
  end

  @doc """
  Function to seed user
  """
  def comeon_user(params) do
    case Repo.get_by(User, name: params.name) do
      nil ->
        %User{} |> User.changeset(params) |> Repo.insert!()

      data ->
        data
    end
  end

  @doc """
  Function to seed resource
  """

  def comeon_resource(data) do
    module = data.__struct__

    case Repo.get_by(module, name: data.name) do
      nil ->
        Repo.insert!(data)

      data ->
        data
    end
  end
end
