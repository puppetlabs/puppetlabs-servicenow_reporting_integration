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
  def settings
    settings_file = Puppet[:confdir] + '/servicenow_reporting.yaml'
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

      # TODO: Add oauth_token decryption here
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

  def requested_status?(status, corrective_change, noop_pending)
    change_types = settings['incident_creation_report_attributes']

    if change_types.include? 'none'
      Puppet.info('servicenow reporting: incident_creation_report_attributes includes \'none\'.')
      return false
    elsif change_types.include? 'unchanged'
      Puppet.info('servicenow reporting: incident_creation_report_attributes includes \'unchanged\'.')
      return true
    elsif change_types.include? 'all'
      change_types = ['failed_changes', 'corrective_changes', 'intentional_changes', 'pending_changes']
    end

    report_on_noop = change_types.include? 'pending_changes'

    if status == 'failed' && change_types.include?('failed_changes')
      Puppet.info('servicenow reporting: decision: reportable failure')
      return true
    end

    if noop_pending && !report_on_noop
      Puppet.info('servicenow reporting: pending change reporting disabled')
      return false
    elsif noop_pending && report_on_noop
      # This branch is a problem. Currently, given the data available to report
      # processors like ours, on noop runs (pending changes), only corrective
      # changes can generate incidents. An intentional change cannot be detected
      # on a noop run.
      Puppet.info('servicenow reporting: pending change reporting enabled')
      return reportable_change?(change_types, status, corrective_change)
    else
      return reportable_change?(change_types, status, corrective_change)
    end
  end
  module_function :requested_status?

  def reportable_change?(change_types, status, corrective_change)
    reportable_change = false
    if corrective_change && change_types.include?('corrective_changes')
      Puppet.info('servicenow reporting: decision: reportable corrective change')
      reportable_change = true
    elsif status == 'changed' && !corrective_change && change_types.include?('intentional_changes')
      Puppet.info('servicenow reporting: decision: reportable intentional change')
      reportable_change = true
    end

    reportable_change
  end
  module_function :reportable_change?
end
