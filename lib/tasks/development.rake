# frozen_string_literal: true

namespace :mirros do
  namespace :dev do
    desc 'Perform an automated setup routine with pre-set settings'
    task :run_setup, %i[orientation name email language local_network_mode] => :environment do |_task, args|
      args.with_defaults(
        :orientation =>  'portrait',
        :name => `git config --get user.name`.chomp!,
        :email => `git config --get user.email`.chomp!,
        :language => 'enGb',
        :local_network_mode => 'off',
      )

      p "Using #{args[:name]} / #{args[:email]} for setup"
      raise ArgumentError if args[:name].empty? || args[:email].empty?

      orientation = args[:orientation]
      p "Using #{orientation} mode"

      p "local network mode #{args[:local_network_mode]}"

      Setting.find_by(slug: 'system_language').update!(value: args[:language])
      Setting.find_by(slug: 'system_timezone').update!(value: 'Europe/Berlin')
      Setting.find_by(slug: 'personal_privacyConsent').update!(value: 'yes')
      Setting.find_by(slug: 'network_connectiontype').update!(value: 'lan')
      Setting.find_by(slug: 'network_localmode').update!(value: args[:local_network_mode])
      Setting.find_by(slug: 'personal_email').update!(value: args[:email])
      Setting.find_by(slug: 'personal_name').update!(value: args[:name])

      SystemState.find_or_initialize_by(variable: 'client_display')
                 .update(
                   value: {
                     orientation: orientation,
                     width: orientation.eql?('portrait') ? 1080 : 1920,
                     height: orientation.eql?('portrait') ? 1920 : 1080
                   }
                 )

      StateCache.put :configured_at_boot, true
      # FIXME: This is a temporary workaround to differentiate between
      # initial setup before first connection attempt and subsequent network problems.
      # Remove once https://gitlab.com/glancr/mirros_api/issues/87 lands

      # Test online status
      SettingExecution::Network.send(:validate_connectivity)

      sleep 2
      # System has internet connectivity, complete seed and send setup mail
      CreateDefaultBoardJob.perform_now
      SendWelcomeMailJob.perform_now unless args[:local_network_mode].eql?('on')
      puts 'Setup complete'
    end
  end
end
