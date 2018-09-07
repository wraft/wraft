defmodule StarterWeb.Api.V1.WorkView do
    @moduledoc """
    View module for WorkController.
    """
    use StarterWeb, :view
  require IEx
    def render("work.json", %{work: work}) do
      %{
        company: work.company,
        location: work.location,
        designation: work.designation,
        from_date: work.from_date,
        to_date: work.to_date,
        description: work.description,
        current_job: work.current_job,
        days_worked: work.days_worked,
        file: work.file,
        user_id: work.user_id,   
        user: %{id: work.user.id, mobile: work.user.mobile, email: work.user.email}
      }
    end
  end