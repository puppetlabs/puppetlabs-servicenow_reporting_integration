require 'puppet/util/servicenow'

Puppet::Reports.register_report(:servicenow) do
  desc 'Create Servicenow incidents from Puppet reports'

  include Puppet::Util::Servicenow

  def process
    settings_hash = settings

    case settings_hash['operation_mode']
    when 'event_management'
      process_event_management(settings_hash)
    else
      # default to incident management
      process_incident_management(settings_hash)
    end
  rescue StandardError => e
    Puppet.err "servicenow report processor error: #{e}\n#{e.backtrace}"
  end

  def process_event_management(settings_hash)
    event_data = {
      'source'   => 'Puppet',
      'type'     => 'node_report',
      # 5 => 'OK' severity
      'severity' => '5',
      'node'     => host,
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
    endpoint = "https://#{settings_hash['instance']}/api/global/em/jsonv2"

    Puppet.info(sn_log_entry("attempting to send the #{event_data['type']} event on #{endpoint}"))

    response = do_snow_request(endpoint,
                               'Post',
                               { records: [event_data] },
                               user: settings_hash['user'],
                               password: settings_hash['password'],
                               oauth_token: settings_hash['oauth_token'])

    raise "Failed to send the event. Error from #{endpoint} (status: #{response.code}): #{response.body}" if response.code.to_i >= 300

    Puppet.info(sn_log_entry('successfully sent the event'))

    true
  end

  def process_incident_management(settings_hash)
    incident_creation_conditions = settings_hash['incident_creation_conditions']

    unless incident_creation_conditions.is_a?(Array)
      raise "settings['incident_creation_conditions'] must be an array, got #{incident_creation_conditions}"
    end

    Puppet.info(sn_log_entry("incident creation conditions: #{incident_creation_conditions}"))

    satisfied_conditions = calculate_satisfied_conditions(status, resource_statuses, incident_creation_conditions)

    if satisfied_conditions.empty?
      Puppet.info(sn_log_entry('decision: Do not create incident'))
      # do not create an incident
      return false
    end

    short_description_status = noop_pending ? 'pending changes' : status
    incident_data = {
      short_description: "Puppet run report (status: #{short_description_status}) for node #{host} (report time: #{format_report_timestamp(time, metrics)})",
      # Ideally, we'd like to link to the specific report here. However, fine-grained PE console links are
      # unstable even for Y PE releases (e.g. the link is different for PE 2019.2 and PE 2019.8). Thus, the
      # best and most stable solution we can do (for now) is the description you see here.
      description: incident_description(satisfied_conditions, settings_hash),
      caller_id: settings_hash['caller_id'],
      category: settings_hash['category'],
      subcategory: settings_hash['subcategory'],
      contact_type: settings_hash['contact_type'],
      state: settings_hash['state'],
      impact: settings_hash['impact'],
      urgency: settings_hash['urgency'],
      assignment_group: settings_hash['assignment_group'],
      assigned_to: settings_hash['assigned_to'],
    }

    endpoint = "https://#{settings_hash['instance']}/api/now/table/incident"

    Puppet.info(sn_log_entry("attempting to create incident on #{endpoint}"))

    response = do_snow_request(endpoint,
                               'Post',
                               incident_data,
                               user: settings_hash['user'],
                               password: settings_hash['password'],
                               oauth_token: settings_hash['oauth_token'])

    raise "Incident creation failed. Error from #{endpoint} (status: #{response.code}): #{response.body}" if response.code.to_i >= 300

    response_data = JSON.parse(response.body)['result']

    Puppet.info(sn_log_entry("created incident #{response_data['number']}"))

    true
  end
end
