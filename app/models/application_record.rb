class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  after_commit :broadcast, if: :broadcastable?

  def broadcastable?
    [
      Widget,
      WidgetInstance,
      Source,
      SourceInstance,
      InstanceAssociation,
      Setting
    ].include? self.class
  end

  def broadcast
    res_class = "#{self.class}Resource".safe_constantize
    return if res_class.nil?

    res = res_class.new(reload, nil) # Reload from DB to ensure we're not pushing stale data
    includes = case res
               when SourceInstanceResource
                 %w[source widget_instances instance_associations]
               when WidgetInstanceResource
                 %w[widget source_instances instance_associations]
               when InstanceAssociationResource
                 %w[source_instance widget_instance]
               else
                 []
               end
    serialized_res = JSONAPI::ResourceSerializer.new(res_class, include: includes).serialize_to_hash(res)
    ActionCable.server.broadcast 'updates',
                                 payload: serialized_res,
                                 type: destroyed? ? 'deletion' : 'update'
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast #{self.class} #{id} update: #{e.message}"
  end
end
