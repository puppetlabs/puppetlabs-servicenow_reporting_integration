require 'puppet/util/servicenow'

Puppet::Reports.register_report(:servicenow) do
  desc 'Create Servicenow incidents from Puppet reports'

  include Puppet::Util::Servicenow

  def process
    settings_hash = settings

    incident_creation_conditions = settings_hash['incident_creation_conditions']
    unless incident_creation_conditions.is_a?(Array)
      raise "settings['incident_creation_conditions'] must be an array, got #{incident_creation_conditions}"
    end

    Puppet.info(sn_log_entry("incident creation conditions: #{incident_creation_conditions}"))

    unless create_incident?(status, resource_statuses, incident_creation_conditions)
      Puppet.info(sn_log_entry('decision: Do not create incident'))
      # do not create an incident
      return false
    end

    short_description_status = noop_pending ? 'pending changes' : status
    incident_data = {
      short_description: "Puppet run report #{time} (status: #{short_description_status}) for node #{host}",
      # Ideally, we'd like to link to the specific report here. However, fine-grained PE console links are
      # unstable even for Y PE releases (e.g. the link is different for PE 2019.2 and PE 2019.8). Thus, the
      # best and most stable solution we can do (for now) is the description you see here.
      description: "See PE console for the full report. You can access the PE console at #{settings_hash['pe_console_url']}",
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

    return true
  rescue StandardError => e
    Puppet.err "Could not send incident to Servicenow: #{e}\n#{e.backtrace}"
  end
end
