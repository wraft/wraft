defmodule Starter.WorkManagement.Work do
    @moduledoc """
    This is the Work model.
    """
    use Ecto.Schema
    use Arc.Ecto.Schema
    import Ecto.Changeset
    alias Starter.WorkManagement
require IEx
    schema "works" do
        field :company, :string
        field :location, :string
        field :designation, :string
        field :from_date, :date
        field :to_date, :date
        field :description, :string
        field :file, StarterWeb.WorkFileUploader.Type
        field :days_worked, :integer
        field :current_job, :boolean, default: false
        field :currently_working, :boolean, virtual: true
        belongs_to :user, Starter.UserManagement.User

        timestamps()
    end

    def changeset(work, attrs \\ %{}) do
        work
        |> cast(attrs, [:company, :location, :designation, :from_date, :to_date, :description, :currently_working, :current_job])
        |> cast_attachments(attrs, [:file])
        |> validate_required([:company, :location, :designation, :from_date, :description])
        |> current_status()
    end

    defp current_status(current_changeset) do
        case current_changeset.changes.currently_working do
            true ->
                updated_changeset =
                put_change(
                    current_changeset,
                    :current_job,
                    true
                )  
                validate_from_date(updated_changeset)
                |> ensure_no_to_date() 
                |> calculate_days_current_job()
            
            false ->
                current_changeset
                |> validate_from_date()
                |> validate_to_date()
                |> ensure_to_date_latest()
                |> calculate_days()
                
        end
    end
       
        defp validate_from_date(new_changeset) do
            now = Timex.now
            # {:ok, from_date} = Timex.parse(new_changeset.changes.from_date, "{YYYY}-{M}-{D}")
            from_date = new_changeset.changes.from_date
            case Timex.before?(from_date, now) do
                true -> 
                    new_changeset
                false ->
                    add_error(new_changeset, :from_date, "Invalid date")
            end
        end

        defp validate_to_date(new_changeset) do
            now = Timex.now  
            # {:ok, to_date} = Timex.parse(new_changeset.changes.to_date, "{YYYY}-{M}-{D}")
            if Map.has_key?(new_changeset.changes, :to_date) do
                to_date = new_changeset.changes.to_date
                case Timex.before?(to_date, now) do
                    true -> 
                        new_changeset
                    false ->
                        add_error(new_changeset, :to_date, "Invalid date")
                end
            else 
                add_error(new_changeset, :to_date, "Please enter the date up until you worked here, if you dont work here anymore.")

            end
        end

        defp ensure_no_to_date(new_changeset) do
            if Map.has_key?(new_changeset.changes, :to_date) do
                add_error(new_changeset, :to_date, "You cannot have a 'To date', if you are currently worrking here.!!")
            else
                new_changeset
            end
        end

        defp calculate_days_current_job(current_changeset) do
            now = Timex.now
            from_date = current_changeset.changes.from_date
            experience = 
            Timex.diff(Timex.now, from_date, :days)
             put_change(
                current_changeset,
                :days_worked,
                experience
            )  
        end

        def calculate_days(current_changeset) do
            from_date = current_changeset.changes.from_date
            to_date = current_changeset.changes.to_date
            experience = 
            Timex.diff(to_date, from_date, :days)
             put_change(
                current_changeset,
                :days_worked,
                experience
            )  
        end

        def ensure_to_date_latest(current_changeset) do
            from_date = current_changeset.changes.from_date
            to_date = current_changeset.changes.to_date
            case Timex.before?(from_date, to_date) do
                true -> 
                    current_changeset
                false ->
                    add_error(current_changeset, :to_date, "'To Date' should be the latest date..!")
            end
        end
end
