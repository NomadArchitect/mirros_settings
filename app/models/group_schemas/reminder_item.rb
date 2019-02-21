module GroupSchemas
  class ReminderItem < ApplicationRecord
    belongs_to :reminder_list

    # Override ActiveModel method to ensure ISO8601 formatted dates. Required since jsonapi-resources calls
    # JSON.generate instead of ActiveSupport methods, thus calling to_s on the date fields which outputs
    # "yyyy-mm-dd hh:mm:ss UTC" which in turn breaks JS' Date parsing in all browsers except Chrome.
    # see https://github.com/cerebris/jsonapi-resources/blob/d2db72b370b9150e3363e3cd406294e9cacfcc2f/lib/jsonapi/acts_as_resource_controller.rb#L241
    def serializable_hash(options = nil)
      base = super({except: %i[uid calendar_id dtstart dtend]}.merge(options || {}))
      base.merge(
        dtstart: dtstart.iso8601,
        dtend: dtend.iso8601
      )
    end
  end
end

