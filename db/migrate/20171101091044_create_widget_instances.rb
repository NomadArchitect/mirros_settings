class CreateWidgetInstances < ActiveRecord::Migration[5.1]
  def change
    create_table :widget_instances do |t|
      t.string :widget_id
      t.string :title
      t.boolean :showtitle, default: true # JSONAPI resources seems to hiccup on underscored field names, see https://github.com/cerebris/jsonapi-resources/pull/158
      t.json :configuration, default: {}
      t.json :position
      t.timestamps
    end

    add_index :widget_instances, :widget_id
  end
end
