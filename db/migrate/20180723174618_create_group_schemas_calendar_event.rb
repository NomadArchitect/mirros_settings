# frozen_string_literal: true

class CreateGroupSchemasCalendarEvent < ActiveRecord::Migration[5.2]
  def change
    create_table :group_schemas_calendar_events, id: false do |t|
      t.string :uid, primary_key: true
      t.references :calendar, type: :string
      t.datetime :dtstart
      t.datetime :dtend
      t.boolean :all_day
      t.string :summary
      t.text :description
      t.string :location
      t.timestamps
    end
  end
end
