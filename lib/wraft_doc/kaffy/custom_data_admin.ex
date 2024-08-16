defmodule WraftDoc.Kaffy.CustomDataAdmin do
  @moduledoc false

  import Ecto.Query

  alias WraftDoc.Repo
  alias WraftDoc.WaitingLists.WaitingList

  def get_pending_user_count do
    query = from(u in WaitingList, where: u.status == :pending, select: count(u.id))
    Repo.one(query)
  end

  def get_user_registration_chart_data do
    now = DateTime.utc_now()
    today = DateTime.to_date(now)
    thirty_days_ago = Timex.shift(today, days: -30)

    # Convert to NaiveDateTime using a function call for readability
    {:ok, thirty_days_ago_naive} = NaiveDateTime.new(thirty_days_ago, ~T[00:00:00])

    user_counts_per_day_query =
      from(u in WaitingList,
        where: u.inserted_at >= ^thirty_days_ago_naive,
        group_by: fragment("date(?)", u.inserted_at),
        select: {fragment("date(?)", u.inserted_at), count(u.id)}
      )

    user_counts_per_day = Repo.all(user_counts_per_day_query)

    x_axis_labels = Enum.map(user_counts_per_day, fn {date, _count} -> date end)
    y_axis_values = Enum.map(user_counts_per_day, fn {_date, count} -> count end)

    %{
      x: x_axis_labels,
      y: y_axis_values,
      y_title: "Number of Users"
    }
  end
end
