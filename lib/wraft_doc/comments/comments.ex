defmodule WraftDoc.Comments do
  @moduledoc """
  Module for handling comment-related operations, including creation and retrieval.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Comments.Comment
  alias WraftDoc.Documents
  alias WraftDoc.Repo

  @doc """
  Create a comment
  """
  # TODO - improve tests
  def create_comment(%{current_org_id: <<_::288>> = org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)
    insert_comment(current_user, params)
  end

  def create_comment(%{current_org_id: nil} = current_user, params),
    do: insert_comment(current_user, params)

  def create_comment(_, _), do: {:error, :fake}

  @doc """
  Updates a comment
  """
  @spec update_comment(Comment.t(), map) :: Comment.t()
  def update_comment(comment, params) do
    comment
    |> Comment.changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, comment} ->
        Repo.preload(comment, [{:user, :profile}, {:resolver, :profile}])
    end
  end

  @doc """
  Deletes a coment
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Get a comment by uuid.
  """
  # TODO - improve tests
  @spec get_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def get_comment(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Comment, id: id, organisation_id: org_id) do
      %Comment{} = comment -> comment
      _ -> {:error, :invalid_id, "Comment"}
    end
  end

  def get_comment(<<_::288>>, _), do: {:error, :fake}
  def get_comment(_, %{current_org_id: _}), do: {:error, :invalid_id, "Comment"}
  def get_comment(_, _), do: {:error, :invalid_id, "Comment"}

  @doc """
  Fetch a comment and all its details.
  """
  # TODO - improve tests
  @spec show_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def show_comment(id, user) do
    with %Comment{} = comment <- get_comment(id, user) do
      Repo.preload(comment, [{:user, :profile}, {:resolver, :profile}])
    end
  end

  @doc """
  Comments under a master
  """
  # TODO - improve tests
  @spec comment_index(User.t(), map()) :: Scrivener.Page.t()
  def comment_index(%{current_org_id: org_id}, %{"master_id" => master_id} = params) do
    query =
      from(c in Comment,
        where: c.organisation_id == ^org_id,
        where: c.master_id == ^master_id,
        where: c.is_parent == true,
        order_by: [desc: c.inserted_at],
        preload: [{:user, :profile}, {:resolver, :profile}]
      )

    Repo.paginate(query, params)
  end

  def comment_index(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_index(_, %{"master_id" => _}), do: {:error, :fake}
  def comment_index(_, _), do: {:error, :invalid_data}

  @doc """
   Replies under a comment
  """
  # TODO - improve tests
  @spec comment_replies(%{current_org_id: any}, map) :: Scrivener.Page.t()
  def comment_replies(
        %{current_org_id: org_id} = user,
        %{"master_id" => master_id, "comment_id" => comment_id} = params
      ) do
    with %Comment{id: parent_id} <- get_comment(comment_id, user) do
      query =
        from(c in Comment,
          where: c.organisation_id == ^org_id,
          where: c.master_id == ^master_id,
          where: c.is_parent == false,
          where: c.parent_id == ^parent_id,
          order_by: [desc: c.inserted_at],
          preload: [{:user, :profile}, {:resolver, :profile}]
        )

      Repo.paginate(query, params)
    end
  end

  def comment_replies(_, %{"master_id" => _, "comment_id" => _}), do: {:error, :fake}
  def comment_replies(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_replies(_, _), do: {:error, :invalid_data}

  # Private
  defp insert_comment(current_user, params) do
    current_user
    |> build_assoc(:comments)
    |> Comment.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        Repo.preload(comment, [{:user, :profile}, {:resolver, :profile}])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Resolve a comment by marking it as resolved and assigning the resolver.
  """
  @spec resolve_comment(Comment.t(), User.t()) :: Comment.t() | {:error, Ecto.Changeset.t()}
  def resolve_comment(
        %Comment{master_id: master_id, user_id: creator_id} = comment,
        %User{id: resolver_id} = current_user
      ) do
    with %{allowed_users: allowed_users} = _instance <-
           Documents.get_instance(master_id, current_user),
         :ok <- check_resolver(resolver_id, creator_id, allowed_users) do
      comment
      |> Comment.changeset(%{resolved?: true, resolver_id: resolver_id})
      |> Repo.update()
      |> case do
        {:ok, comment} ->
          Repo.preload(comment, [{:user, :profile}, {:resolver, :profile}])

        {:error, _} = changeset ->
          changeset
      end
    end
  end

  defp check_resolver(resolver_id, creator_id, allowed_users) do
    if resolver_id in allowed_users || creator_id == resolver_id do
      :ok
    else
      {:error,
       {401,
        %{
          "errors" => "You are not authorized for this action.!"
        }}}
    end
  end
end
