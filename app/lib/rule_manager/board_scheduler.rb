# frozen_string_literal: true

module RuleManager
  class BoardScheduler
    RULE_EVALUATION_TAG = 'system-board-rule-evaluation'
    ROTATION_INTERVAL_TAG = 'system-board-rotation'
    ROTATION_INTERVAL_RELOAD_TAG = 'system-board-rotation-reload'

    # Schedules an hourly job that evaluates current board rules.
    # The first matched rule determines the new active board.
    #
    # @return [Boolean] returns the log entry status, which assumes all went well
    def self.start_rule_evaluation
      return if job_running? RULE_EVALUATION_TAG

      Rufus::Scheduler.singleton.cron '* * * * *', tag: RULE_EVALUATION_TAG do
        rule_applied = false
          Board.all.each do |board|
          # TODO: Extend logic for rule sets in each board.

          # Date-based rules take precedence over recurring rules.
          if board.rules.where(provider: 'system', field: 'dateAndTime').any?(&:evaluate)
            Setting.find_by(slug: :system_activeboard).update(value: board.id)
            rule_applied = true
            break
          end
          # TODO: this only gets time-based rules for the board and runs them in sequential order.
          if board.rules.where(provider: 'system', field: 'timeOfDay').any?(&:evaluate)
            Setting.find_by(slug: :system_activeboard).update(value: board.id)
            rule_applied = true
            break
          end
        end

        Setting.find_by(slug: :system_activeboard).update(value: Board.first.id) unless rule_applied
      end
      Rails.logger.info "scheduled job #{RULE_EVALUATION_TAG}"
    end

    # Stops the rule evaluation job.
    #
    # @return [Boolean] whether the log entry succeeded.
    def self.stop_rule_evaluation
      return unless job_running? RULE_EVALUATION_TAG

      Rufus::Scheduler.s.cron_jobs(tag: RULE_EVALUATION_TAG).each(&:unschedule)
      Rails.logger.info "stopped job #{RULE_EVALUATION_TAG}"
    end

    # Starts the board rotation job.
    #
    # @param interval [String]
    # @return [Boolean] whether the log entry succeeded.
    def self.start_rotation_interval(interval = nil)
      return if job_running? ROTATION_INTERVAL_TAG

      parsed = Rufus::Scheduler.parse(interval || SettingsCache.s[:system_boardrotationinterval])
      Rufus::Scheduler.singleton.every parsed, tag: ROTATION_INTERVAL_TAG do
        active_board_setting = Setting.find_by(slug: :system_activeboard)
        boards = Board.ids
        new_board_id = boards[boards.find_index(active_board_setting.value.to_i) + 1] || boards.first
        active_board_setting.update(value: new_board_id)
      end
      Rails.logger.info "scheduled job #{ROTATION_INTERVAL_TAG} every #{parsed} seconds"

      # FIXME: Workaround for WPE crashes, check if this is necessary once we have 2.30.2 running
      # Definitely remove once https://github.com/Igalia/cog/issues/230 is in stable
      return if job_running? ROTATION_INTERVAL_RELOAD_TAG

      Rufus::Scheduler.singleton.every '1h', tag: ROTATION_INTERVAL_RELOAD_TAG do
        System.reload_browser if ENV['SNAP'] # only do something when in snap env
        Rails.logger.info 'Reloaded the attached browser via DBus'
      end
      Rails.logger.info "scheduled job #{ROTATION_INTERVAL_RELOAD_TAG} every hour"

    rescue ArgumentError => e
      Rails.logger.error "failed to start rotation job: #{e.message}"
    end

    # Stops the rotation job.
    #
    # @return [Boolean] whether the log entry succeeded.
    def self.stop_rotation_interval
      [ROTATION_INTERVAL_TAG, ROTATION_INTERVAL_RELOAD_TAG].each do |tag|
        next unless job_running? tag
        Rufus::Scheduler.s.every_jobs(tag: tag).each(&:unschedule)
        Rails.logger.info "stopped job #{tag}"
        end
    end

    def self.manage_jobs(rotation_active: false)
      if rotation_active
        stop_rule_evaluation
        start_rotation_interval
      else
        stop_rotation_interval
        start_rule_evaluation
      end
    end

    def self.job_running?(tag)
      Rufus::Scheduler.singleton.jobs(tag: tag).present?
    end
  end
end
