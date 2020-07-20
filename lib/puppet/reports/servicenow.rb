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
      # Ideally, we'd like to link to the specific report here. However, fine-grained PE console links are
      # unstable even for Y PE releases (e.g. the link is different for PE 2019.2 and PE 2019.8). Thus, the
      # best and most stable solution we can do (for now) is the description you see here.
      description: "See PE console for the full report. You can access the PE console at #{settings_hash['pe_console_url']}",
      caller: settings_hash['caller'],
      category: settings_hash['category'],
      contact_type: settings_hash['contact_type'],
      state: settings_hash['state'],
      impact: settings_hash['impact'],
      urgency: settings_hash['urgency'],
      assignment_group: settings_hash['assignment_group'],
      assigned_to: settings_hash['assigned_to'],
    }

    endpoint = "https://#{settings_hash['instance']}/api/now/table/incident"

    response = do_snow_request(endpoint,
                               'Post',
                               incident_data,
                               user: settings_hash['user'],
                               password: settings_hash['password'],
                               oauth_token: settings_hash['oauth_token'])

    raise "Incident creation failed. Error from #{endpoint} (status: #{response.code}): #{response.body}" if response.code.to_i >= 300
    return true
  rescue StandardError => e
    Puppet.err "Could not send incident to Servicenow: #{e}\n#{e.backtrace}"
  end
end
