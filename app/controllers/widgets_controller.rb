# frozen_string_literal: true

# Controller for Widget actions.
class WidgetsController < ApplicationController
  include JSONAPI::ActsAsResourceController

  def update
    if params[:data][:attributes][:active].eql? false
      Widget.find(params[:id]).widget_instances.each(&:destroy)
    end
    super
  end
end
