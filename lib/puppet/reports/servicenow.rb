require 'puppet/util/servicenow'

Puppet::Reports.register_report(:servicenow) do
  desc 'Create Servicenow incidents from Puppet reports'

  include Puppet::Util::Servicenow

  def process
    unless status != 'unchanged' || noop_pending
      # do not create an incident
      return false
    end
    settings_hash = settings
    short_description_status = (status == 'unchanged') ? 'pending changes' : status
    incident_data = {
      short_description: "Puppet run report #{time} (status: #{short_description_status}) for node #{host}",
      description: "See [code]<a class='web' target='_blank' href='https://#{settings_hash['pe_console']}/#/inspect/report/#{job_id}/metrics'>Report</a>[/code] for more details",
      caller: settings_hash['caller'],
      category: settings_hash['category'],
      contact_type: settings_hash['contact_type'],
      state: settings_hash['state'],
      impact: settings_hash['impact'],
      urgency: settings_hash['urgency'],
      assignment_group: settings_hash['assignment_group'],
      assigned_to: settings_hash['assigned_to'],
    }

    endpoint = "https://#{settings_hash['snow_instance']}/api/now/table/incident"

    response = do_snow_request(endpoint,
                               'Post',
                               incident_data,
                               user: settings_hash['user'],
                               password: settings_hash['password'],
                               oauth_token: settings_hash['oauth_token'])

    raise "Incident creation failed. Error from #{endpoint} (status: #{response.code}): #{response.body}" if response.code.to_i >= 400
    return true
  rescue StandardError => e
    Puppet.err "Could not send incident to Servicenow: #{e}\n#{e.backtrace}"
  end
end
