require 'puppet'
require 'puppet/util'
require 'fileutils'
require 'yaml'
require 'json'
require 'net/http'
require 'openssl'
require 'base64'

# hiera-eyaml requires. Note that newer versions of puppet-agent
# ship with the hiera-eyaml gem so these should work.
require 'hiera/backend/eyaml/options'
require 'hiera/backend/eyaml/parser/parser'
require 'hiera/backend/eyaml/subcommand'

# servicenow.rb
module Puppet::Util::Servicenow
  def sn_log_entry(msg)
    "servicenow report processor: #{msg}"
  end
  module_function :sn_log_entry

  def settings(settings_file = Puppet[:confdir] + '/servicenow_reporting.yaml')
    settings_hash = YAML.load_file(settings_file)

    # Since we also support hiera-eyaml encrypted passwords, we'll want to decrypt
    # the password before passing it into the request. In order to do that, we first
    # check if hiera-eyaml's configured on the node. If yes, then we run the password
    # through hiera-eyaml's parser. The parser will decrypt the password if it is
    # encrypted; otherwise, it will leave it as-is so that plain-text passwords are
    # unaffected.
    hiera_eyaml_config = nil
    begin
      # Note: If hiera-eyaml config doesn't exist, then load_config_file returns
      # the hash {:options => {}, :sources => []}
      hiera_eyaml_config = Hiera::Backend::Eyaml::Subcommand.load_config_file
    rescue StandardError => e
      raise "error reading the hiera-eyaml config: #{e}"
    end
    unless hiera_eyaml_config[:sources].empty?
      # hiera_eyaml config exists so run the password through the parser. Note that
      # we chomp the password to support syntax like:
      #
      #   password: >
      #       ENC[Y22exl+OvjDe+drmik2XEeD3VQtl1uZJXFFF2NnrMXDWx0csyqLB/2NOWefv
      #       NBTZfOlPvMlAesyr4bUY4I5XeVbVk38XKxeriH69EFAD4CahIZlC8lkE/uDh
      #       ...
      #
      # where the '>' will add a trailing newline to the encrypted password.
      #
      # Note that ServiceNow passwords can't contain a newline so chomping's still OK
      # for plain-text passwords.
      Hiera::Backend::Eyaml::Options.set(hiera_eyaml_config[:options])
      parser = Hiera::Backend::Eyaml::Parser::ParserFactory.hiera_backend_parser

      if (password = settings_hash['password'])
        password_tokens = parser.parse(password.chomp)
        password = password_tokens.map(&:to_plain_text).join
        settings_hash['password'] = password
      end

      if (oauth_token = settings_hash['oauth_token'])
        oauth_token_tokens = parser.parse(oauth_token.chomp)
        oauth_token = oauth_token_tokens.map(&:to_plain_text).join
        settings_hash['oauth_token'] = oauth_token
      end
    end

    settings_hash
  end
  module_function :settings

  def do_snow_request(uri, http_verb, body, user: nil, password: nil, oauth_token: nil)
    uri = URI.parse(uri)

    Net::HTTP.start(uri.host,
                    uri.port,
                    use_ssl: uri.scheme == 'https',
                    verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      header = { 'Content-Type' => 'application/json' }
      # Interpolate the HTTP verb and constantize to a class name.
      request_class_string = "Net::HTTP::#{http_verb.capitalize}"
      request_class = Object.const_get(request_class_string)
      # Add uri, fields and authentication to request
      request = request_class.new("#{uri.path}?#{uri.query}", header)
      request.body = body.to_json
      if oauth_token
        request['Authorization'] = "Bearer #{oauth_token}"
      else
        request.basic_auth(user, password)
      end
      # Make request to ServiceNow and return response
      http.request(request)
    end
  end
  module_function :do_snow_request

  # Returns a hash of event conditions
  def calculate_event_conditions(resource_statuses)
    event_conditions = {
      'corrective_changes'          => false,
      'intentional_changes'         => false,
      'pending_corrective_changes'  => false,
      'pending_intentional_changes' => false,
    }
    resource_statuses.each do |_, resource|
      resource.events.each do |event|
        next if event.status == 'failure' || event.status == 'audit'
        # event.status == 'success' || 'noop'. Either way, we found a satisfying
        # change condition so determine its name
        change_condition = event.corrective_change ? 'corrective_changes' : 'intentional_changes'
        if event.status == 'noop'
          change_condition = "pending_#{change_condition}"
        end
        event_conditions[change_condition] = true
      end
    end
    event_conditions
  end
  module_function :calculate_event_conditions

  # Returns an array of satisfied conditions
  # Note that the 'never' condition will be overridden by any other valid condition
  def calculate_satisfied_conditions(report_status, resource_statuses, incident_creation_conditions)
    # Some incident creation conditions depend on the resource events. Thus, we go ahead
    # and evaluate these 'event' conditions _before_ evaluating the incident creation
    # conditions so we can iterate through the resource events only once. This results in
    # cleaner code for a negligible performance hit, where the performance hit occurs if the
    # incident creation conditions do _not_ contain an 'event' condition.
    #
    # Note that event_conditions is a hash of <condition> => <satisfied?>
    event_conditions = calculate_event_conditions(resource_statuses)
    satisfied_conditions = incident_creation_conditions.select do |condition|
      if condition == 'always'
        true
      elsif condition == 'never'
        false
      elsif condition == 'failures'
        report_status == 'failed'
      elsif event_conditions.key?(condition)
        event_conditions[condition]
      else
        # We should never hit this code-path
        Puppet.warning(sn_log_entry("unknown incident creation conditon: #{condition}"))
        false
      end
    end
    Puppet.info(sn_log_entry("satisfied conditions: #{satisfied_conditions}"))
    satisfied_conditions
  end
  module_function :calculate_satisfied_conditions

  def incident_description(satisfied_conditions, settings_hash)
    'This incident was created based on the following conditions: '\
    "#{satisfied_conditions.join(', ')}. See the PE console for the full report. "\
    "You can access the PE console at #{settings_hash['pe_console_url']}."
  end
  module_function :incident_description

  def format_report_timestamp(time, metrics)
    total_time = time + metrics['time']['total']
    short_date_time = total_time.strftime('%F %H:%M:%S %Z')
    short_date_time.gsub('UTC', 'Z')
  end
  module_function :format_report_timestamp
end
