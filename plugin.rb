# name: discourse-chargebee
# about: A super simple plugin to consume chargebee events
# version: 0.0.1
after_initialize do

  add_model_callback User, :after_create do
    if invite = Invite.find_by_email(email)
      self.chargebee_id = invite.chargebee_id
      save
    end
  end

  module ::Chargebee
    class Engine < ::Rails::Engine
      engine_name "chargebee"
      isolate_namespace Chargebee
    end

    class Event < ActiveRecord::Base
    end
  end

  require_dependency 'application_controller'

  class Chargebee::ChargebeeEventsController < ::ApplicationController
    requires_plugin 'discourse-chargebee'

    skip_before_filter :verify_authenticity_token, only: [:create]

    def create
      e = Chargebee::Event.create!(json_data: params.slice(
        :id, :occurred_at, :source, :object, :content, :event_type, :webhook_status
      ))

      case(e.json_data['event_type'])
        when 'customer_created'
          invite_user(e.json_data['content']['customer']['email'])
        when 'subscription_cancelled'
          user = User.find_by_email(e.json_data['content']['customer']['email'])
          disable_user(user) if user
        when 'subscription_reactivated'
          user = User.find_by_email(e.json_data['content']['customer']['email'])
          enable_user(user) if user
      end
      render status: :ok, json: params
    end

    private
      def invite_user(email)
       Invite.invite_by_email(email, Discourse.system_user)
      end

      def disable_user(user)
        guardian.ensure_can_suspend!(user)
        user.suspended_till = 10000.days.from_now
        user.suspended_at = DateTime.now
        user.save!
        user.revoke_api_key
        StaffActionLogger.new(Discourse.system_user).log_user_suspend(user, 'Subscription expired')
        MessageBus.publish "/logout", user.id, user_ids: [user.id]
      end

      def enable_user(user)
        guardian.ensure_can_suspend!(user)
        user.suspended_till = nil
        user.suspended_at = nil
        user.save!
        StaffActionLogger.new(Discourse.system_user).log_user_unsuspend(user)
      end
  end

  Chargebee::Engine.routes.draw do
    post '/' => 'chargebee_events#create'
  end

  Discourse::Application.routes.append do
    mount ::Chargebee::Engine, at: "/chargebee"
  end
end
