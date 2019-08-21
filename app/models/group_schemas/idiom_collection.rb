module GroupSchemas
  class IdiomCollection < ApplicationRecord
    validates :type, presence: true
    has_one :record_link, as: :recordable, dependent: :destroy
    has_many :items, class_name: 'IdiomCollectionItem', dependent: :delete_all, autosave: true
  end
end
