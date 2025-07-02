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
  def create_comment(%{current_org_id: <<_::288>> = organisation_id} = current_user, params) do
    params
    |> Map.put("organisation_id", organisation_id)
    |> then(&insert_comment(current_user, &1))
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
    |> Comment.changeset(ensure_is_parent(params))
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, comment} ->
        preload_comment_profiles(comment)
    end
  end

  @doc """
  Deletes a coment
  """
  def delete_comment(%Comment{} = comment), do: Repo.delete(comment)

  @doc """
  Get a comment by uuid.
  """
  # TODO - improve tests
  @spec get_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def get_comment(<<_::288>> = id, %{current_org_id: organisation_id}) do
    case Repo.get_by(Comment, id: id, organisation_id: organisation_id) do
      %Comment{} = comment -> get_children(comment, organisation_id)
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
      preload_comment_profiles(comment)
    end
  end

  @doc """
  Comments under a master
  """
  # TODO - improve tests
  @spec comment_index(User.t(), map()) :: Scrivener.Page.t()
  def comment_index(%{current_org_id: organisation_id}, %{"master_id" => master_id} = params) do
    query =
      from(c in Comment,
        where: c.organisation_id == ^organisation_id,
        where: c.master_id == ^master_id,
        order_by: [desc: c.inserted_at],
        preload: [{:user, :profile}, {:resolver, :profile}]
      )

    query
    |> Repo.paginate(params)
    |> Map.update!(:entries, &build_nested_comments/1)
  end

  def comment_index(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_index(_, %{"master_id" => _}), do: {:error, :fake}
  def comment_index(_, _), do: {:error, :invalid_data}

  @doc """
   Replies under a comment
  """
  # TODO - improve tests
  @spec comment_replies(User.t(), map()) :: Scrivener.Page.t()
  def comment_replies(
        %{current_org_id: organisation_id} = user,
        %{"master_id" => master_id, "id" => comment_id} = params
      ) do
    with %Comment{id: parent_id} <- get_comment(comment_id, user) do
      query =
        from(c in Comment,
          where: c.organisation_id == ^organisation_id,
          where: c.master_id == ^master_id,
          where: c.is_parent == false,
          where: c.parent_id == ^parent_id,
          order_by: [desc: c.inserted_at],
          preload: [{:user, :profile}, {:resolver, :profile}]
        )

      Repo.paginate(query, params)
    end
  end

  def comment_replies(_, %{"master_id" => _, "id" => _}), do: {:error, :fake}
  def comment_replies(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_replies(_, _), do: {:error, :invalid_data}

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
          preload_comment_profiles(comment)

        {:error, _} = changeset ->
          changeset
      end
    end
  end

  defp insert_comment(current_user, %{"master_id" => document_id} = params) do
    doc_version_id = Documents.get_latest_version_id(document_id)

    params =
      params
      |> ensure_is_parent()
      |> Map.put("doc_version_id", doc_version_id)

    current_user
    |> build_assoc(:comments)
    |> Comment.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        preload_comment_profiles(comment)

      {:error, _} = changeset ->
        changeset
    end
  end

  defp build_nested_comments(comments) do
    {parent_comments, child_comments} =
      Enum.split_with(comments, &(&1.is_parent == true))

    children_by_parent = Enum.group_by(child_comments, & &1.parent_id)

    Enum.map(parent_comments, fn %{id: parent_id} = parent ->
      children = Map.get(children_by_parent, parent_id, [])
      Map.put(parent, :children, children)
    end)
  end

  defp get_children(%Comment{id: comment_id} = comment, organisation_id) do
    children_query =
      from(c in Comment,
        where: c.organisation_id == ^organisation_id,
        where: c.parent_id == ^comment_id,
        order_by: [desc: c.inserted_at],
        preload: [{:user, :profile}, {:resolver, :profile}]
      )

    children_query
    |> Repo.all()
    |> then(&Map.put(comment, :children, &1))
  end

  defp check_resolver(resolver_id, creator_id, allowed_users) do
    if resolver_id in allowed_users || creator_id == resolver_id do
      :ok
    else
      {:error, :fake}
    end
  end

  defp preload_comment_profiles(comment),
    do: Repo.preload(comment, [{:user, :profile}, {:resolver, :profile}])

  defp ensure_is_parent(%{"parent_id" => _} = params), do: Map.put(params, "is_parent", true)
  defp ensure_is_parent(params), do: Map.put(params, "is_parent", false)
end
