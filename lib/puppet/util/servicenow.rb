require 'digest'
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

  def do_snow_request(uri, http_verb, body, user: nil, password: nil, oauth_token: nil, skip_cert_check: false, read_timeout: 60, write_timeout: 60)
    uri = URI.parse(uri)
    verify_mode = skip_cert_check ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER

    # We're going to set the connect timeout and the read timeout to the same
    # value, because in most user's minds these are functionally the same
    # timeout, and until we get some specific push for separating them out
    # we don't want to make the module more complex for users to understand.
    opts = {
      use_ssl:         uri.scheme == 'https',
      verify_mode:     verify_mode,
      read_timeout:    read_timeout,
      connect_timeout: read_timeout,
      ssl_timeout:     read_timeout,
      write_timeout:   write_timeout,
    }

    Net::HTTP.start(uri.host,
                    uri.port,
                    opts) do |http|
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

  def human_readable_event_summary(resource_statuses)
    summary = ''
    resource_statuses.values.select { |resource| resource.out_of_sync == true || resource.failed == true }.each do |resource|
      resource_summary = ''
      resource.events.each do |event|
        resource_summary << "#{['', resource.containment_path, "#{event.property}: #{event.message}"].flatten.join('/')}\n"
      end
      resource_summary << "  Resource Definition: #{resource.file}:#{resource.line}\n"
      summary << resource_summary
    end
    summary
  end
  module_function :human_readable_event_summary

  def additional_info_resource_events(resource_statuses)
    corrective_changes          = []
    intentional_changes         = []
    pending_corrective_changes  = []
    pending_intentional_changes = []
    failures                    = []
    resource_statuses.values.select { |resource| resource.out_of_sync == true || resource.failed == true }.each do |resource|
      event_summary = { 'resource'         => resource.resource,
                        'containing_class' => resource.resource_type,
                        'containment_path' => resource.containment_path,
                        'file'             => resource.file,
                        'line'             => resource.line }
      if resource.failed
        failures << event_summary
      elsif resource.events.select { |event| event.status == 'noop' }.count > 0
        (resource.corrective_change == true) ? (pending_corrective_changes << event_summary) : (pending_intentional_changes << event_summary)
      else
        (resource.corrective_change == true) ? (corrective_changes << event_summary) : (intentional_changes << event_summary)
      end
    end
    { 'corrective_changes'               => corrective_changes,
      'corrective_changes_hash'          => corrective_changes.empty? ? [] : Digest::SHA1.hexdigest(corrective_changes.to_json.chars.sort.join),
      'intentional_changes'              => intentional_changes,
      'intentional_changes_hash'         => intentional_changes.empty? ? [] : Digest::SHA1.hexdigest(intentional_changes.to_json.chars.sort.join),
      'pending_corrective_changes'       => pending_corrective_changes,
      'pending_corrective_changes_hash'  => pending_corrective_changes.empty? ? [] : Digest::SHA1.hexdigest(pending_corrective_changes.to_json.chars.sort.join),
      'pending_intentional_changes'      => pending_intentional_changes,
      'pending_intentional_changes_hash' => pending_intentional_changes.empty? ? [] : Digest::SHA1.hexdigest(pending_intentional_changes.to_json.chars.sort.join),
      'failures'                         => failures,
      'failures_hash'                    => failures.empty? ? [] : Digest::SHA1.hexdigest(failures.to_json.chars.sort.join) }
  end
  module_function :additional_info_resource_events

  # Returns a hash of event conditions
  def calculate_event_conditions(resource_statuses)
    event_conditions = {
      'failures'                    => false,
      'corrective_changes'          => false,
      'intentional_changes'         => false,
      'pending_corrective_changes'  => false,
      'pending_intentional_changes' => false,
    }

    resource_statuses.values.each do |resource|
      resource.events.each do |event|
        next if event.status == 'audit'
        # event.status == 'success' || 'noop'. Either way, we found a satisfying
        # change condition so determine its name
        if event.status == 'failure'
          change_condition = 'failures'
        else
          change_condition = event.corrective_change ? 'corrective_changes' : 'intentional_changes'
          change_condition = "pending_#{change_condition}" if event.status == 'noop'
        end
        event_conditions[change_condition] = true
      end
    end

    event_conditions
  end
  module_function :calculate_event_conditions

  def event_type(resource_statuses, status)
    case status
    when 'unchanged'
      'node_report_unchanged'
    when 'failed'
      'node_report_failed'
    when 'changed'
      event_conditions = calculate_event_conditions(resource_statuses)
      applicable_event_conditions = event_conditions.select { |_, condition| condition == true }.keys
      return 'node_report_corrective_changes' if applicable_event_conditions.include?('corrective_changes')
      'node_report_intentional_changes'
    end
  end
  module_function :event_type

  def event_severity_string(event_severity_string)
    severity_settings = {
      'Clear' => 0,
      'Critical' => 1,
      'Major' => 2,
      'Minor' => 3,
      'Warning' => 4,
      'OK' => 5,
    }
    severity_settings[event_severity_string]
  end

  def calculate_event_severity(resource_statuses, settings_hash, transaction_completed)
    # https://docs.servicenow.com/bundle/paris-it-operations-management/page/product/event-management-operator/concept/operator-events-alerts.html
    # 0 => Clear....(The alert no longer needs action.)
    # 1 => Critical.(The resource is either not functional or critical problems are imminent.)
    # 2 => Major....(Major functionality is severely impaired or performance has degraded.)
    # 3 => Minor....(Partial, non-critical loss of functionality or performance degradation occurred.)
    # 4 => Warning..(Attention is required, even though the resource is still functional.)
    # 5 => OK.......(No severity. An alert is created. The resource is still functional.)
    event_conditions = calculate_event_conditions(resource_statuses)
    # return no_changes_event_severity in the case that there are no changes
    return event_severity_string(settings_hash['failures_event_severity']) if catalog_compilation_failure?(resource_statuses, transaction_completed)
    return event_severity_string(settings_hash['no_changes_event_severity']) unless event_conditions.values.any?
    event_severity_string(event_conditions.select { |_, exists| exists == true }
                    .map { |condition, _| settings_hash[condition + '_event_severity'] }.sort.first)
  end
  module_function :calculate_event_severity

  # Returns an array of satisfied conditions
  # Note that the 'never' condition will be overridden by any other valid condition
  def calculate_satisfied_conditions(report_status, resource_statuses, incident_creation_conditions, transaction_completed)
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
        report_status == 'failed' || catalog_compilation_failure?(resource_statuses, transaction_completed)
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

  def report_description(settings_hash, resource_statuses, transaction_completed)
    resourse_status_summary = human_readable_event_summary(resource_statuses)
    labels                  = description_report_labels(resource_statuses, transaction_completed)
    # Ideally, we'd like to link to the specific report here. However, fine-grained PE console links are
    # unstable even for Y PE releases (e.g. the link is different for PE 2019.2 and PE 2019.8). Thus, the
    # best and most stable solution we can do (for now) is the description you see here.
    description =  labels.nil? ? '' : labels
    description << "\n\nEnvironment: #{environment}"
    description << "\n\nSee the PE console for the full report. You can access the PE console at #{settings_hash['pe_console_url']}."
    description << "\n\nResource Statuses:\n#{resourse_status_summary}" unless resourse_status_summary.empty?
    description << "\n\nLog Output:\n#{log_messages}" if catalog_compilation_failure?(resource_statuses, transaction_completed)
    description << "\n\n== Facts ==\n#{selected_facts(settings_hash)}"
    description
  end
  module_function :report_description

  def facts
    # This is a cheat to make it easier to do test mocks.
    Puppet::Node::Facts.indirection.find(host).values
  end

  def selected_facts(settings_hash, facts_query = nil, format = nil)
    include_facts = facts_query.nil? ? settings_hash['include_facts'] : facts_query
    output_format = format.nil? ? settings_hash['facts_format'].to_sym : format.to_sym

    selected_facts = {}

    if [include_facts].flatten.first == 'all'
      facts
    else
      include_facts.each do |name|
        value = facts.dig(*name.split('.'))
        selected_facts[name] = value unless value.nil?
      end
    end

    # json and object are primarily to support either internal uses like further
    # processing on selected facts, or giving to the facts to a machine
    # processor like an event engine.
    case output_format
    when :yaml
      selected_facts.to_yaml
    when :pretty_json
      JSON.pretty_generate(selected_facts)
    when :json
      selected_facts.to_json
    when :object
      selected_facts
    else
      selected_facts
    end
  end
  module_function :selected_facts

  def event_additional_information(settings_hash, resource_statuses, transaction_completed)
    additional_information = {}
    # If we wish to add other top level keys to the additional information field, add them here.
    # Include all facts since this field is not intended for humans.
    additional_information['environment'] = environment
    additional_information['report_labels'] = additional_info_report_labels(resource_statuses, transaction_completed)
    additional_information.merge!(selected_facts(settings_hash, nil, :object))
    additional_information.merge!(additional_info_resource_events(resource_statuses))
    JSON.pretty_generate(additional_information)
  end
  module_function :event_additional_information

  def format_report_timestamp(time, metrics)
    total_time = time + metrics['time']['total']
    short_date_time = total_time.strftime('%F %H:%M:%S %Z')
    short_date_time.gsub('UTC', 'Z')
  end
  module_function :format_report_timestamp

  def calculate_report_message_key_hash(report_status, resource_statuses)
    # The report message key hash consists of all the fields relevant to
    # determining a report's uniqueness. In our case, this is the report
    # status and the resource events.
    report_message_key_hash = {
      'status'          => report_status,
      'resource_events' => nil,
    }

    resource_events = []
    resource_statuses.values.each do |resource|
      resource.events.each do |event|
        # Some event fields are not relevant when it comes to determining
        # whether two reports are identical. We delete these unnecessary
        # event fields before adding the event.
        event_hash = event.to_data_hash
        event_hash.delete('historical_value')
        event_hash.delete('message')
        event_hash.delete('time')
        event_hash.delete('redacted')

        resource_events << event_hash
      end
    end
    report_message_key_hash['resource_events'] = resource_events

    report_message_key_hash
  end
  module_function :calculate_report_message_key_hash

  def report_labels(resource_statuses, transaction_completed)
    event_conditions = calculate_event_conditions(resource_statuses).select { |_, present| present == true }
    labels = event_conditions.keys
    labels << 'catalog_failure' if catalog_compilation_failure?(resource_statuses, transaction_completed)
    labels
  end
  module_function :report_labels

  def description_report_labels(resource_statuses, transaction_completed)
    labels = report_labels(resource_statuses, transaction_completed)
    "Report Labels:\n\t#{labels.join("\n\t")}" unless labels.empty?
  end
  module_function :description_report_labels

  def additional_info_report_labels(resource_statuses, transaction_completed)
    labels = report_labels(resource_statuses, transaction_completed)
    labels.join(', ')
  end
  module_function :additional_info_report_labels

  def log_messages
    logs.map { |entry| entry.message }.join("\n")
  end
  module_function :log_messages

  def catalog_compilation_failure?(resource_statuses, transaction_completed)
    resource_statuses.empty? && !transaction_completed
  end
  module_function :catalog_compilation_failure?

  def environment_matched?(environment, allow, block)
    return true if allow == 'none' || block == 'all'
    return false if block == 'none' || allow == 'all'
    return true if File.fnmatch(block, environment)
    return false if File.fnmatch(allow, environment)
  rescue e
    raise e.message, 'Error with environment filter. Please look over allow_list and block_list configurations'
  end
  module_function :environment_matched?

  def env_filter_not_allowed?(environment, allow_list, block_list)
    blocked = false
    if allow_list.length >= block_list.length
      allow_list.zip(block_list) do |allow, block|
        blocked = environment_matched?(environment, allow, block)
      end
    elsif block_list.length > allow_list.length
      block_list.zip(allow_list) do |block, allow|
        blocked = environment_matched?(environment, block, allow)
      end
    end
    Puppet.info(sn_log_entry("Environment filter not allowed: #{blocked}"))
    blocked
  end
  module_function :env_filter_not_allowed?
end

# takes the instance string from the settings and prepends 'https://' if not already present.
def instance_with_protocol(instance)
  if instance[0..7] == 'https://'
    instance
  else
    'https://' << instance
  end
end
