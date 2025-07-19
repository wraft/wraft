defmodule WraftDoc.Notifications.Definition do
  @moduledoc """
  Provides a declarative way to define notifications.
  Example:
    defnotification :user_joins_wraft do
      title "Welcome to Wraft"
      message fn %{name: name} ->
        "Welcome to Wraft, \#{name}! We're excited to have you on board."
      end
      channels [:in_app, :email]
      email_template :welcome_email
      email_subject "Welcome to Wraft!"
      # Optional handlers
      before_send fn notification ->
        # Custom logic before sending
        {:ok, notification}
      end
      after_send fn result ->
        # Custom logic after sending
        :ok
      end
    end
  """

  defmacro __using__(_opts) do
    quote do
      import WraftDoc.Notifications.Definition
      Module.register_attribute(__MODULE__, :notification_types, accumulate: true)

      @before_compile WraftDoc.Notifications.Definition
    end
  end

  defmacro __before_compile__(env) do
    types = Module.get_attribute(env.module, :notification_types)

    quote do
      def notification_types, do: unquote(types)

      def get_notification(_), do: nil
    end
  end

  defmacro defnotification(type, do: block) do
    quote do
      @notification_types unquote(type)

      def get_notification(unquote(type)) do
        notification = %{
          type: unquote(type),
          title: nil,
          message: nil,
          channels: [:in_app],
          email_template: nil,
          email_subject: nil,
          before_send: nil,
          after_send: nil,
          recipients: nil,
          priority: :medium,
          conditions: nil
        }

        var!(config) = notification
        unquote(block)
        var!(config)
      end
    end
  end

  defmacro title(text) do
    quote do
      var!(config) = Map.put(var!(config), :title, unquote(text))
    end
  end

  defmacro message(message_value) do
    quote do
      var!(config) = Map.put(var!(config), :message, unquote(message_value))
    end
  end

  defmacro channels(channels) do
    quote do
      var!(config) = Map.put(var!(config), :channels, unquote(channels))
    end
  end

  defmacro email_template(template) do
    quote do
      var!(config) = Map.put(var!(config), :email_template, unquote(template))
    end
  end

  defmacro email_subject(subject) do
    quote do
      var!(config) = Map.put(var!(config), :email_subject, unquote(subject))
    end
  end

  defmacro before_send(handler) do
    quote do
      var!(config) = Map.put(var!(config), :before_send, unquote(handler))
    end
  end

  defmacro after_send(handler) do
    quote do
      var!(config) = Map.put(var!(config), :after_send, unquote(handler))
    end
  end

  defmacro recipients(recipients_config) do
    quote do
      var!(config) = Map.put(var!(config), :recipients, unquote(recipients_config))
    end
  end

  defmacro priority(priority_level) do
    quote do
      var!(config) = Map.put(var!(config), :priority, unquote(priority_level))
    end
  end

  defmacro conditions(conditions_config) do
    quote do
      var!(config) = Map.put(var!(config), :conditions, unquote(conditions_config))
    end
  end
end
