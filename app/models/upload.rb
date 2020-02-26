# frozen_string_literal: true

class Upload < ApplicationRecord
  has_one_attached :file, dependent: :destroy

  delegate :content_type, to: :file

  def file_url
    return unless file.attached?

    if file.image? && !file.content_type.include?('svg')
      Rails.application.routes.url_helpers.rails_representation_url(
        file.variant(resize: '1920x1920').processed,
        host: ActiveStorage::Current.host
      )
    else
      Rails.application.routes.url_helpers.rails_blob_url(
        file,
        host: ActiveStorage::Current.host
      )
    end
  end

  def purge_and_destroy
    file.purge
    destroy
  end
end
