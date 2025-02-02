# frozen_string_literal: true

require 'dbus'

module NetworkManager
  # High-level commands. Proxied NetworkManager D-Bus methods are excluded from
  # RubyResolve inspections to prevent RuboCop error messages.
  class Bus
    include Constants
    include Helpers
    attr_reader :wifi_interface

    CONNECTION_TYPE_WIFI = '802-11-wireless'
    CONNECTION_TYPE_ETHERNET = '802-3-ethernet'
    VALID_CONNECTION_TYPES = [CONNECTION_TYPE_WIFI, CONNECTION_TYPE_ETHERNET]
    WIFI_CONNECT_TIMEOUT = 45 # seconds
    WIFI_SCAN_TIMEOUT = 20 # seconds
    DISCARDED_SSIDS = ['glancr setup', ''].freeze

    def self.service_bus
      DBus::ASystemBus.new['org.freedesktop.NetworkManager']
    end

    # TODO: Refactor to less lines if object is just needed for a single interface
    # see https://www.rubydoc.info/github/mvidner/ruby-dbus/file/doc/Reference.md#Errors
    def initialize
      @nm_service = self.class.service_bus
      @nm_iface = @nm_service[ObjectPaths::NETWORK_MANAGER][NmInterfaces::NETWORK_MANAGER]
      @nm_settings_iface = @nm_service[ObjectPaths::NM_SETTINGS][NmInterfaces::SETTINGS]

      wifi_device_list = list_devices[:wifi].first # FIXME: This just picks the first listed wifi interface
      @wifi_interface = wifi_device_list&.fetch(:interface)
      @wifi_device = wifi_device_list&.fetch(:path)
    end

    def state_hash
      # TODO: Do we need to include connectivity, or does NmState cover all requirements?
      connectivity_state = connectivity
      {
        state: state,
        connectivity: connectivity_state.eql?(NmConnectivityState::LIMITED) ? connectivity_from_dns : connectivity_state,
        wifi_signal: wifi_status,
        primary_connection: primary_connection_as_model
      }
    end

    # Adds the predefined setup and LAN connections if they do not exist yet.
    def add_predefined_connections
      [GLANCRSETUP_CONNECTION, GLANCRLAN_CONNECTION].each do |connection|
        id = connection['connection']['id']
        next unless uuid_for_connection(id).nil?

        connection_path = add_connection(connection)
        uuid = settings_for_connection_path(connection_path)['connection']['uuid']
        Cache.store_network id, uuid
      end
    end

    def delete_all_connections
      @nm_settings_iface['Connections'].each do |connection_path|
        connection_if = @nm_service[connection_path][NmInterfaces::SETTINGS_CONNECTION]
        connection_if.Delete
      end
    end

    # @param [String] ssid SSID of the access point for which a new connection should be established.
    # @param [String] password Passphrase for this access point. @see https://developer.gnome.org/NetworkManager/1.2/ref-settings.html#id-1.4.3.31.1
    def activate_new_wifi_connection(ssid, password)
      # Ensures we don't end up with two connection profiles for the same SSID.
      if Cache.fetch_network ssid
        delete_connection ssid
      end
      # D-Bus proxy calls String.bytesize, so we can't use symbol keys.
      # noinspection RubyStringKeysInHashInspection
      conn = { '802-11-wireless-security' => { 'psk' => password } }
      ap = ap_object_path_for_ssid(ssid)
      if ap.blank?
        Rails.logger.warn "AP for given SSID #{ssid} not known yet, initiating scan"
        ap = scan_for_ssid(ssid)
      end
      # noinspection RubyResolve
      @nm_iface.AddAndActivateConnection(conn, @wifi_device, ap)
    end

    # Activates a NetworkManager connection with the given ID. No-op if the connection is already active.
    # @param [String] id ID of the connection to activate.
    # @return [String] The new active connection path
    def activate_connection(id)
      connection_path = connection_object_path(connection_id: id)
      # noinspection RubyResolve
      @nm_iface.ActivateConnection(connection_path, '/', '/')
    end

    # @param [String] id The id of the connection that should be deactivated
    # @return [nil]
    def deactivate_connection(id)
      matches = @nm_iface['ActiveConnections'].select { |connection| active_connection_has_id? connection, id }
      # noinspection RubyResolve
      @nm_iface.DeactivateConnection(matches.first) unless matches.empty?
    end

    # Deletes a connection from NetworkManager
    # @param [String] id  The ID of the connection that should be deleted.
    # @return [nil]
    def delete_connection(id)
      connection_path = connection_object_path connection_id: id
      connection_if = @nm_service[connection_path][NmInterfaces::SETTINGS_CONNECTION]
      connection_if.Delete
    end

    # In case a connection object path is stale and no longer present on NMs
    # side, NM would throw misleading errors about the Properties interface
    # missing from this object. In that case, the connection is a) not active
    # and b) probably not the connection we are looking for.
    # @param [String] id Name of the connection to check.
    # @return [Boolean] Whether the connection is active.
    def connection_active?(id)
      @nm_iface['ActiveConnections'].any? { |connection| active_connection_has_id? connection, id }
    rescue StandardError => e
      Rails.logger.error "#{__method__} probably stale connection #{id}: #{e.message}"
      false
    end

    def connecting?
      state.eql?(NmState::CONNECTING)
    end

    def connected_local?
      state.eql?(NmState::CONNECTED_LOCAL)
    end

    def connected_site?
      state.eql?(NmState::CONNECTED_SITE)
    end

    def connected?
      state.eql?(NmState::CONNECTED_GLOBAL)
    end

    def any_connectivity?
      state >= NmState::CONNECTING
    end

    def list_devices
      devices = {
        wifi: [],
        ethernet: []
      }
      # noinspection RubyResolve
      @nm_iface.GetDevices.each do |dev|
        nm_dev_i = @nm_service[dev][NmInterfaces::DEVICE]
        device_state = nm_dev_i['State']
        next unless device_state >= NMDeviceState::DISCONNECTED

        dev_info = { interface: nm_dev_i['Interface'], state: device_state, path: dev }
        case nm_dev_i['DeviceType']
        when NmDeviceType::ETHERNET
          devices[:ethernet] << dev_info
        when NmDeviceType::WIFI
          devices[:wifi] << dev_info
        else
          # TODO: Maybe add support for additional devices later.
        end
      end
      devices
    end

    # Lists WiFi networks visible to the primary WiFi device.
    # @return [Array<Hash>]  A list of access points with their SSID, signal strength and if they require a password.
    def list_wifi_networks
      access_points = list_access_point_paths.map! do |ap_path|
        ap_if = self.class.service_bus[ap_path][NmInterfaces::ACCESS_POINT]
        {
          ssid: ap_if['Ssid'].pack('U*'),
          encryption: ap_if['RsnFlags'] > 0, # ruby-dbus converts hexadecimal notation to integer.
          signal: ap_if['Strength'].to_i
        }
      end
      # Drop the setup AP and hidden SSIDs from the results.
      access_points.reject { |wifi| DISCARDED_SSIDS.include? wifi[:ssid] }
    end

    # Request the primary WiFi device to rescan for access points.
    # @return [Hash] The CLOCK_BOOTTIME timestamp of the last scan before the request.
    def request_scan
      nm_wifi_if = @nm_service[@wifi_device][NmInterfaces::DEVICE_WIRELESS]
      last_scan = nm_wifi_if['LastScan']

      Thread.new do
        wifi_device_if = @nm_service[@wifi_device][NmInterfaces::DEVICE]
        active_wifi_connection_path = wifi_device_if['ActiveConnection']
        Thread.current.exit if active_wifi_connection_path.eql?('/')
        active_connection_if = @nm_service[active_wifi_connection_path][NmInterfaces::CONNECTION_ACTIVE]

        connection_uuid = active_connection_if['Uuid']
        # noinspection RubyResolve
        @nm_iface.DeactivateConnection(active_wifi_connection_path)
        # noinspection RubyResolve
        nm_wifi_if.RequestScan({})

        started_scanning = DateTime.now
        while nm_wifi_if['LastScan'].eql?(last_scan) && started_scanning > 30.seconds.ago
          sleep 0.5
        end

        nm_settings_i = @nm_service[ObjectPaths::NM_SETTINGS][NmInterfaces::SETTINGS]
        # noinspection RubyResolve
        connection_to_activate = nm_settings_i.GetConnectionByUuid(connection_uuid)
        # noinspection RubyResolve
        @nm_iface.ActivateConnection(connection_to_activate, @wifi_device, '/')

        Thread.current.exit
      end

      { last_scan: last_scan }
    end

    # Queries The primary WiFi device when it last scanned for access points.
    # @return [Hash] The CLOCK_BOOTTIME in milliseconds since the last scan.
    def last_scan
      { last_scan: @nm_service[@wifi_device][NmInterfaces::DEVICE_WIRELESS]['LastScan'] }
    end

    # Retrieves SSID and signal strength of the currently active AccessPoint.
    # Returns nil for both values if no access point is active or an error occurred.
    # @return [Hash] Connected SSID and its signal strength in percent (e.g. 70)
    def wifi_status
      return { ssid: nil, signal: nil } if @wifi_device.nil?

      nm_wifi_if = @nm_service[@wifi_device][NmInterfaces::DEVICE_WIRELESS]
      active_ap_path = nm_wifi_if['ActiveAccessPoint']
      return { ssid: nil, signal: nil } if active_ap_path.eql?('/')

      ap_if = @nm_service[active_ap_path][NmInterfaces::ACCESS_POINT]
      {
        ssid: ap_if['Ssid'].pack('U*'), signal: ap_if['Strength'].to_i
      }
    rescue DBus::Error => e
      Rails.logger.error e.message
      { ssid: nil, signal: nil }
    end

    def settings_for_connection_path(connection_path)
      retry_wrap max_attempts: 3 do
        connection_iface = @nm_service[connection_path][NmInterfaces::SETTINGS_CONNECTION]
        # noinspection RubyResolve
        connection_iface.GetSettings
      end
    end

    def uuid_for_connection(id)
      result = nil
      @nm_settings_iface['Connections'].each do |connection_path|
        settings = settings_for_connection_path connection_path
        if settings['connection']['id'].eql?(id)
          result = settings['connection']['uuid']
          break
        end
      end
      result
    end

    # @see https://developer-old.gnome.org/NetworkManager/stable/ref-dbus-active-connections.html
    # @param [String] ac_path D-Bus active connection object.
    def model_for_active_connection(ac_path)
      connection_iface = @nm_service[ac_path][NmInterfaces::CONNECTION_ACTIVE]
      # Don't expose tunnel/bridge connections that might pop up in network-manager.
      return unless VALID_CONNECTION_TYPES.include?(connection_iface['Type'])

      attributes = connection_iface.all_properties
      ip4_address = ip4_address_from_config_path attributes['Ip4Config']
      ip6_address = ip6_address_from_config_path attributes['Ip6Config']

      ::NmNetwork.new attributes, ip4_address, ip6_address, ac_path
    end

    def primary_connection_as_model
      connection = primary_connection
      if connection.eql?('/')
        nil
      else
        model_for_active_connection(connection)
      end
    end

    # @param [String,nil] connection_id The ID of a NetworkManager connection, or nil.
    # @param [String,nil] connection_uuid The UUID of a NetworkManager connection, or nil,
    # @return [String] The DBus object path for this connection.
    def connection_object_path(connection_id: nil, connection_uuid: nil)
      connection_uuid ||= Cache.fetch_network connection_id
      raise ArgumentError, "Probably invalid connection ID #{connection_id}, could not get UUID" if connection_uuid.nil?

      nm_settings_i = @nm_service[ObjectPaths::NM_SETTINGS][NmInterfaces::SETTINGS]
      # noinspection RubyResolve
      nm_settings_i.GetConnectionByUuid(connection_uuid)
    end

    def connectivity_check_available?
      @nm_iface['ConnectivityCheckAvailable']
    rescue DBus::Error => _e
      # NM 1.2.2 doesn't have this property, and the snap version disables this
      # feature anyway.
      false
    end

    def connectivity
      @nm_iface['Connectivity']
    end

    def state
      state = @nm_iface['State']
      # NetworkManager sometimes sends CONNECTING state over DBus *after* it has
      # activated a connection with CONNECTED_GLOBAL. This forces a manual refresh
      # after 30 seconds to avoid a stale state.
      ForceNmStateCheckJob.set(wait: 30.seconds).perform_later if state.eql?(Constants::NmState::CONNECTING)

      state
    end

    def primary_connection
      @nm_iface['PrimaryConnection']
    end

    def nm_version
      @nm_iface['Version']
    end

    private

    # Checks if a given active connection path has the given ID.
    # @see https://developer-old.gnome.org/NetworkManager/stable/ref-dbus-active-connections.html
    # @param [String] ac_path a valid D-Bus active connection object.
    # @param [String] id The connection ID.
    def active_connection_has_id?(ac_path, id)
      @nm_service[ac_path][NmInterfaces::CONNECTION_ACTIVE]['Id'].eql? id
    end

    # List all access points currently available on the primary NetworkManager Wifi device. Includes hidden SSIDs.
    # @return [Array] List of DBus object paths.
    def list_access_point_paths
      attempts = 0
      begin
        nm_wifi_i = @nm_service[@wifi_device][NmInterfaces::DEVICE_WIRELESS]
        # noinspection RubyResolve
        nm_wifi_i.GetAllAccessPoints
      rescue DBus::Error => e
        sleep 1
        retry if (attempts += 1) <= 3

        raise e
      end
    end

    # @param [String] config_path D-Bus path to an IP4Config object
    # @see https://developer-old.gnome.org/NetworkManager/stable/ref-dbus-ip4-configs.html
    def ip4_address_from_config_path(config_path)
      ip4_interface = @nm_service[config_path][NmInterfaces::IP4CONFIG]
      # TODO: This only returns the first address without the prefix, maybe extend it to handle the whole array
      ip4_interface['AddressData'].first&.dig('address')
    end

    # @param [String] config_path D-Bus path to an IP6Config object
    # @see https://developer-old.gnome.org/NetworkManager/stable/ref-dbus-ip6-configs.html
    def ip6_address_from_config_path(config_path)
      ip6_interface = @nm_service[config_path][NmInterfaces::IP6CONFIG]
      # TODO: This only returns the first address without the prefix, maybe extend it to handle the whole array
      ip6_interface['AddressData'].first&.dig('address')
    end

    # @param [String] ssid
    # @return [String, nil] The DBus object path for the given connection or nil if NM does not have it.
    def ap_object_path_for_ssid(ssid)
      candidates = []
      list_access_point_paths.each do |ap_path|
        details = ap_details(ap_path)
        candidates.push(details) if details.dig(:ssid).eql?(ssid.to_s)
      end
      candidates.empty? ? nil : candidates.max { |c| c[:strength] }[:ap_path]
    end

    # @param [String] ap_path Valid DBus access point object path
    # @return [Hash] Hash containing the given path, ssid as String and strength as Integer.
    def ap_details(ap_path)
      nm_ap_i = @nm_service[ap_path][NmInterfaces::ACCESS_POINT]
      {
        ap_path: ap_path,
        ssid: nm_ap_i['Ssid']&.pack('U*'), # NM returns byte-array
        strength: nm_ap_i['Strength']
      }
    rescue DBus::Error => e
      Rails.logger.error "#{__method__} L:#{__LINE__} #{e.message}"
      {}
    end

    # @param [String] ssid Scan for a given SSID, otherwise do a general scan.
    # @return [String]
    def scan_for_ssid(ssid = '')
      nm_wifi_i = @nm_service[@wifi_device][NmInterfaces::DEVICE_WIRELESS]
      request_scan_for_ssid(dbus_wifi_iface: nm_wifi_i, ssid: ssid)
      time_elapsed = 0
      result = while time_elapsed < WIFI_SCAN_TIMEOUT
                 sleep 2
                 time_elapsed += 2
                 ap_path = ap_object_path_for_ssid(ssid)
                 Rails.logger.warn "searching for #{ssid}, #{time_elapsed} sec elapsed"
                 break ap_path unless ap_path.nil?
               end
      return result if result.present?

      raise StandardError, "NM could not find AP for given SSID #{ssid}"
    end

    # Adds a new connection profile to NetworkManager.
    # @param [Hash] connection_settings The connection settings to use.
    # @return [String] The D-Bus object path of the added connection.
    def add_connection(connection_settings)
      nm_settings_i = @nm_service['/org/freedesktop/NetworkManager/Settings'][NmInterfaces::SETTINGS]
      # noinspection RubyResolve
      nm_settings_i.AddConnection(connection_settings)
    end

    def request_scan_for_ssid(dbus_wifi_iface:, ssid: '')
      # noinspection RubyResolve, RubyStringKeysInHashInspection
      dbus_wifi_iface.RequestScan('ssid' => DBus.variant('aay', [ssid.bytes]))
    rescue DBus::Error => e
      # Device is probably already scanning, avoid error bubbling.
      Rails.logger.error "#{__method__}: #{e.message}"
    end

    def connectivity_from_dns
      ping_address = Resolv::DNS.new.getaddress(::System::API_HOST).to_s # .address returns raw network-byte order
      uri = URI::HTTP.build(host: 'www.gstatic.com', path: '/generate_204')
      if ping_address.eql?(::System::SETUP_IP)
        NmConnectivityState::PORTAL
      elsif Net::HTTP.new(uri.host, uri.port).request_head(uri.path).kind_of?(Net::HTTPSuccess)
        NmConnectivityState::FULL
      else
        NmConnectivityState::UNKNOWN
      end
    rescue StandardError
      NmConnectivityState::NONE
    end
  end
end
