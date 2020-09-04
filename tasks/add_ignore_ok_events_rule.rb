#!/opt/puppetlabs/puppet/bin/ruby

# rubocop:disable Lint/UnderscorePrefixedVariableName

require_relative '../../ruby_task_helper/files/task_helper.rb'
require_relative '../lib/puppet/util/servicenow.rb'
require 'erb'

# This task creates an event rule in Servicenow
class ServiceNowEventRuleCreate < TaskHelper
  def task(name: 'Puppet Node Report - Info',
           description: 'Node reports with severity level \'Ok\'.',
           order: 100,
           user: nil,
           password: nil,
           instance: nil,
           oauth_token: nil,
           _target: nil,
           **_kwargs)

    simple_filter = File.read(File.join(__dir__, '../files/ok_rule_simple_filter.json')).gsub('"', '\"').gsub(%r{\s+}, '')
    event_data = File.read(File.join(__dir__, '../files/event_data.json')).gsub('"', '\"').gsub(%r{\s+}, '')

    # The two variables above 'simple_filter' and 'event_data' are both available inside the erb template function
    # because the current scope binding is passed into the ERB call.
    data = ERB.new(File.read(File.join(__dir__, '../files/add_ignore_event_ok_rule_data.erb'))).result binding

    user        = _target[:user]        if user.nil?
    password    = _target[:password]    if password.nil?
    oauth_token = _target[:oauth_token] if oauth_token.nil?
    instance    = _target[:uri]         if instance.nil?

    uri = "https://#{instance}/api/now/table/em_match_rule"

    begin
      response = Puppet::Util::Servicenow.do_snow_request(uri,
                                                          'POST',
                                                          JSON.parse(data),
                                                          user: user,
                                                          password: password,
                                                          oauth_token: oauth_token)

      raise "Failed to create the rule. Error from #{uri} (status: #{response.code}): #{response.body}" if response.code.to_i >= 300
    rescue => exception
      raise TaskHelper::Error.new('Servicenow Request Error',
                                  'EventRuleCreate/do_snow_request',
                                  exception)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ServiceNowEventRuleCreate.run
end
