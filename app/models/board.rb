# frozen_string_literal: true

# Model for a screen configuration.
class Board < ApplicationRecord
  before_destroy :abort_if_default, :abort_if_active
  has_many :widget_instances, dependent: :destroy
  has_many :rules, dependent: :destroy
  belongs_to :background, # background may be re-used across boards.
             foreign_key: :uploads_id, # use a single table for uploads.
             inverse_of: :boards,
             optional: true # background image is optional.

  def abort_if_default
    return unless default?

    errors.add :base, I18n.t('board.errors.messages.default_board_deletion')
    throw(:abort)
  end

  def abort_if_active
    return unless id.eql?(Setting.value_for(:system_activeboard).to_i)

    errors.add(:base, I18n.t('board.errors.messages.cannot_delete_active_board'))
    throw(:abort)
  end

  def default?
    id.eql?(Board.first.id)
  end
end
