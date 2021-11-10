require 'cgi'
require 'puppet_litmus'
PuppetLitmus.configure!
# The Target class and TargetHelpers module are a useful ways
# for tests to reuse Litmus' helpers when they want to do stuff
# on nodes that may not be the current target host (like e.g.
# the server or the ServiceNow instance).
#
# NOTE: The code here is Litmus' recommended approach for multi-node
# testing (see https://github.com/puppetlabs/puppet_litmus/issues/72).
# We should revisit it once Litmus has a standardized pattern for
# multi-node testing.

class Target
  include PuppetLitmus

  attr_reader :uri

  def initialize(uri)
    @uri = uri
  end

  def bolt_config
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    LitmusHelpers.config_from_node(inventory_hash, @uri)
  end

  # Make sure that ENV['TARGET_HOST'] is set to uri
  # before each PuppetLitmus method call. This makes it
  # so if we have an array of targets, say 'agents', then
  # code like agents.each { |agent| agent.bolt_upload_file(...) }
  # will work as expected. Otherwise if we do this in, say, the
  # constructor, then the code will only work for the agent that
  # most recently set the TARGET_HOST variable.
  PuppetLitmus.instance_methods.each do |name|
    m = PuppetLitmus.instance_method(name)
    define_method(name) do |*args, &block|
      ENV['TARGET_HOST'] = uri
      m.bind(self).call(*args, &block)
    end
  end
end

class TargetNotFoundError < StandardError; end

module TargetHelpers
  def server
    target('server', 'acceptance:provision_vms', 'server')
  end
  module_function :server

  def servicenow_instance
    target('ServiceNow instance', 'acceptance:setup_servicenow_instance', 'servicenow_instance')
  end
  module_function :servicenow_instance

  def target(name, setup_task, role)
    @targets ||= {}

    unless @targets[name]
      # Find the target
      inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
      targets = LitmusHelpers.find_targets(inventory_hash, nil)
      target_uri = targets.find do |target|
        vars = LitmusHelpers.vars_from_node(inventory_hash, target) || {}
        (vars['role'] || []) == role
      end
      unless target_uri
        raise TargetNotFoundError, "none of the targets in 'inventory.yaml' have the '#{role}' role set. Did you forget to run 'rake #{setup_task}'?"
      end
      @targets[name] = Target.new(target_uri)
    end

    @targets[name]
  end
  module_function :target
end

module LitmusHelpers
  extend PuppetLitmus
end

module Helpers
  # params is json
  def curl_get_records(table, query)
    endpoint = "/api/now/table/#{table}"
    query ||= {}.to_json
    query = JSON.parse(query)

    query = query.map do |name, value|
      "#{CGI.escape(name.to_s)}=#{CGI.escape(value.to_s)}"
    end

    query = query.join('&')
    endpt_with_query = query.length > 1 ? "#{endpoint}?#{query}" : endpoint
    full_result = server.run_shell("curl -v -i --insecure -u mock_user:mock_password -X GET https://localhost:8000#{endpt_with_query}")
    full_result = full_result.stdout.split("\n")
    JSON.parse(full_result[full_result.length - 1])['result']
  end
  module_function :curl_get_records

  def get_incident_records(params)
    table = params['table']
    query = params['url_params']

    task_result = curl_get_records(table, query)
    task_result
  end
  module_function :get_incident_records

  def get_records(table, query)
    params = {
      'table' => table,
      'url_params' => {
        'sysparm_query' => query,
        'sysparm_exclude_reference_link' => true,
      }.to_json,
    }

    task_result = curl_get_records(table, params['url_params'])
    task_result
  end
  module_function :get_records

  def get_single_record(table, query)
    snow_err_msg_prefix = "On ServiceNow instance #{servicenow_instance.uri} with table '#{table}', query '#{query}'"

    records = Helpers.get_records(table, query)
    raise "#{snow_err_msg_prefix} expected record matching query but none was found" if records.empty?
    if records.length > 1
      sys_ids = records.map { |record| record['sys_id'] }
      raise "#{snow_err_msg_prefix}: found multiple matching records. sys_ids: #{sys_ids.join(', ')}"
    end

    records[0]
  end
  module_function :get_single_record

  def delete_record(table, sys_id)
    endpoint = "/api/now/table/#{table}/#{sys_id}"
    server.run_shell("curl -v -i --insecure -u mock_user:mock_password -X DELETE https://localhost:8000#{endpoint}")
  end
  module_function :delete_record

  def delete_records(table, query)
    get_records(table, query).each do |record|
      delete_record(table, record['sys_id'])
    end
  end
  module_function :delete_records

  def skip_cert_check?
    # If the uri for the servicenow instance is just the uri for the server with
    # the port at the end, then we assume that it's just the container.
    # The container uses a self signed cert, so we have to skip the cert check.
    servicenow_instance.uri.include? server.uri
  end
  module_function :skip_cert_check?
end
