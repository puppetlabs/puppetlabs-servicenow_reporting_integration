require 'puppet/util/servicenow'

Puppet::Reports.register_report(:servicenow) do
  desc 'Create Servicenow incidents from Puppet reports'

  include Puppet::Util::Servicenow

  def process
    settings_hash = settings

    case settings_hash['operation_mode']
    when 'event_management'
      process_event_management(settings_hash) unless settings_hash['disabled']
    else
      # default to incident management
      process_incident_management(settings_hash)
    end
  rescue StandardError => e
    Puppet.err "servicenow report processor error: #{e}\n#{e.backtrace}"
  end

  def process_event_management(settings_hash)
    event_creation_conditions = settings_hash['event_creation_conditions']

    unless event_creation_conditions.is_a?(Array)
      raise "settings_hash['event_creation_conditions'] must be an array, got #{event_creation_conditions}"
    end

    Puppet.info(sn_log_entry("event creation conditions: #{event_creation_conditions}"))

    satisfied_conditions = calculate_satisfied_conditions(status, resource_statuses, event_creation_conditions, transaction_completed)
    exists_in_blocked_list = env_filter_not_allowed?(environment, settings_hash['allow_list'], settings_hash['block_list'])

    if satisfied_conditions.empty? || exists_in_blocked_list
      Puppet.info(sn_log_entry('decision: Do not create event'))
      # do not create an event
      return false
    end

    event_data = {
      'source'          => 'Puppet',
      'type'            => event_type(resource_statuses, status),
      'severity'        => calculate_event_severity(resource_statuses, settings_hash, transaction_completed).to_s,
      'node'            => host,
      # Source Instance is sent as event_class in the api
      # PuppetDB uses Puppet[:node_name_value] to determine the server name so this should be fine.
      'event_class'     => Puppet[:node_name_value],
      'description'     => report_description(settings_hash, resource_statuses, transaction_completed),
      'additional_info' => event_additional_information(settings_hash, resource_statuses, transaction_completed),
    }

    # Compute the message key hash, which contains all relevant information
    # involved in determining the event's uniqueness. In our case, this
    # information's the node and report.
    message_key_hash = {
      'node'   => host,
      'report' => calculate_report_message_key_hash(status, resource_statuses),
    }

    # Finally calculate the message key. This is the SHA-1 of the message key
    # hash's raw JSON encoding (sorted).
    event_data['message_key'] = Digest::SHA1.hexdigest(message_key_hash.to_json.chars.sort.join)

    # Now send the event
    endpoint = "#{instance_with_protocol(settings_hash['instance'])}/api/global/em/jsonv2"

    Puppet.info(sn_log_entry("attempting to send the #{event_data['type']} event on #{endpoint}"))

    response = do_snow_request(endpoint,
                               'Post',
                               { records: [event_data] },
                               user: settings_hash['user'],
                               password: settings_hash['password'],
                               oauth_token: settings_hash['oauth_token'],
                               skip_cert_check: settings['skip_certificate_validation'],
                               read_timeout: settings['http_read_timeout'],
                               write_timeout: settings['http_write_timeout'])

    raise "Failed to send the event. Error from #{endpoint} (status: #{response.code}): #{response.body}" if response.code.to_i >= 300

    Puppet.info(sn_log_entry('successfully sent the event'))

    true
  end

  def process_incident_management(settings_hash)
    incident_creation_conditions = settings_hash['incident_creation_conditions']

    unless incident_creation_conditions.is_a?(Array)
      raise "settings_hash['incident_creation_conditions'] must be an array, got #{incident_creation_conditions}"
    end

    Puppet.info(sn_log_entry("incident creation conditions: #{incident_creation_conditions}"))

    satisfied_conditions = calculate_satisfied_conditions(status, resource_statuses, incident_creation_conditions, transaction_completed)
    exists_in_blocked_list = env_filter_not_allowed?(environment, settings_hash['allow_list'], settings_hash['block_list'])

    if satisfied_conditions.empty? || exists_in_blocked_list
      Puppet.info(sn_log_entry('decision: Do not create incident'))
      # do not create an incident
      return false
    end

    short_description_status = noop_pending ? 'pending changes' : status
    incident_data = {
      short_description: "Puppet run report (status: #{short_description_status}) for node #{host} environment #{environment} (report time: #{format_report_timestamp(time, metrics)})",
      description: report_description(settings_hash, resource_statuses, transaction_completed),
      caller_id: settings_hash['caller_id'],
      category: settings_hash['category'],
      subcategory: settings_hash['subcategory'],
      contact_type: settings_hash['contact_type'],
      state: settings_hash['state'],
      impact: settings_hash['impact'],
      urgency: settings_hash['urgency'],
      assignment_group: settings_hash['assignment_group'],
      assigned_to: settings_hash['assigned_to'],
      cmdb_ci: host,
    }

    endpoint = "#{instance_with_protocol(settings_hash['instance'])}/api/now/table/incident"

    Puppet.info(sn_log_entry("attempting to create incident on #{endpoint}"))

    response = do_snow_request(endpoint,
                               'Post',
                               incident_data,
                               user: settings_hash['user'],
                               password: settings_hash['password'],
                               oauth_token: settings_hash['oauth_token'],
                               skip_cert_check: settings['skip_certificate_validation'],
                               read_timeout: settings['http_read_timeout'],
                               write_timeout: settings['http_write_timeout'])

    raise "Incident creation failed. Error from #{endpoint} (status: #{response.code}): #{response.body}" if response.code.to_i >= 300

    response_data = JSON.parse(response.body)['result']

    Puppet.info(sn_log_entry("created incident #{response_data['number']}"))

    true
  end
end
