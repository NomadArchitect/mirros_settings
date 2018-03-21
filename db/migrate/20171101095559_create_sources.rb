class CreateSources < ActiveRecord::Migration[5.1]
  def change
    create_table :sources do |t|
      t.string :name
      t.string :creator
      t.string :version
      t.string :website
      t.string :slug

      t.timestamps
    end
  end
end
