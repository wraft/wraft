defmodule WraftDoc.Notifications.Definition do
  @moduledoc """
  Provides a declarative way to define notifications with a DSL for configuring
  message content, delivery channels, email templates, and lifecycle hooks.

  ## Overview

  This module allows you to define notification templates using a clean, declarative
  syntax. Each notification definition specifies how messages should be formatted,
  which channels to use for delivery, and any custom logic to execute during the
  notification lifecycle.

  ## Basic Usage

  ```elixir
  defmodule MyApp.Notifications do
    use WraftDoc.Notifications.Definition

    defnotification "registration.user_joins_wraft" do
      title("Welcome to Wraft")

      message(fn %{user_name: user_name} ->
        "Welcome to Wraft, <strong>user_name</strong> We're excited to have you on board."
      end)

      channels([:in_app, :email])
      email_template(MJML.Welcome)
      email_subject("Welcome to Wraft!")
    end
  end
  ```

  ## Configuration Options

  ### Required Fields

  - `title/1` - The notification title displayed in the UI
  - `message/1` - Either a string or function that returns the message content

  ### Delivery Channels

  - `channels/1` - List of delivery channels: `:in_app`, `:email`, `:sms`, etc.

  ### Email Configuration

  - `email_template/1` - MJML template module for email rendering
  - `email_subject/1` - Email subject line (string or function)

  ### Advanced Options

  - `recipients/1` - Custom recipient selection logic
  - `priority/1` - Notification priority: `:low`, `:medium`, `:high`, `:urgent`
  - `conditions/1` - Conditions that must be met for delivery
  - `before_send/1` - Hook executed before sending notification
  - `after_send/1` - Hook executed after sending notification
  ```
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
