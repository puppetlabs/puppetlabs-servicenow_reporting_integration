require_relative '../lib/puppet/util/servicenow.rb'

# This script is used within the 'validate_cmd' parameter of the settings file's
# File resource

unless ARGV.length == 2
  raise 'Usage: path/to/puppet/ruby validate_settings.rb <temporary_settings_file_path> <validation_table>'
end
temporary_settings_file_path = ARGV[0]
validation_table = ARGV[1]

settings = Puppet::Util::Servicenow.settings(temporary_settings_file_path)

# Validate the PE console URL
begin
  pe_console_url = settings['pe_console_url']
  # The /auth/favicon.ico endpoint is a stable PE console endpoint
  uri = URI.parse("#{pe_console_url}/auth/favicon.ico")
  response = Net::HTTP.start(uri.host,
                             uri.port,
                             use_ssl: uri.scheme == 'https',
                             verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    request = Net::HTTP::Get.new(uri)
    http.request(request)
  end
  if response.code.to_i >= 400
    raise 'the URL points to an invalid PE console instance'
  end
rescue StandardError => e
  raise "failed to validate the PE console url '#{pe_console_url}' via the '/auth/favicon.ico' endpoint: #{e}"
end

if validation_table.empty?
  # User doesn't want to validate the ServiceNow credentials so nothing more needs to be done
  exit 0
end

# Validate the ServiceNow credentials
begin
  endpoint = "https://#{settings['instance']}/api/now/table/#{validation_table}?sysparm_limit=1"
  response = Puppet::Util::Servicenow.do_snow_request(
    endpoint,
    'Get',
    nil,
    user: settings['user'],
    password: settings['password'],
    oauth_token: settings['oauth_token'],
  )
  status_code = response.code.to_i
  if status_code >= 400
    raise "received error response from endpoint #{endpoint} (status: #{status_code}): #{response.body}"
  end
rescue StandardError => e
  raise "failed to validate the ServiceNow credentials: #{e}"
end
