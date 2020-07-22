require 'puppet_litmus'

# The Target class and TargetHelpers module are a useful ways
# for tests to reuse Litmus' helpers when they want to do stuff
# on nodes that may not be the current target host (like e.g.
# the master or the ServiceNow instance).
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
  def master
    target('master', 'acceptance:provision_vms', 'master')
  end
  module_function :master

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
        roles = vars['roles'] || []
        roles.include?(role)
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

module IncidentHelpers
  def get_incidents(query)
    params = {
      'table' => 'incident',
      'url_params' => {
        'sysparm_query' => query,
        'sysparm_exclude_reference_link' => true,
      },
    }

    task_result = servicenow_instance.run_bolt_task('servicenow_tasks::get_records', params)
    task_result.result['result']
  end
  module_function :get_incidents

  def get_single_incident(query)
    snow_err_msg_prefix = "On ServiceNow instance #{servicenow_instance.uri} with query '#{query}'"

    incidents = IncidentHelpers.get_incidents(query)
    raise "#{snow_err_msg_prefix} expected incident matching query but none was found" if incidents.empty?
    if incidents.length > 1
      sys_ids = incidents.map { |incident| incident['sys_id'] }
      raise "#{snow_err_msg_prefix}: found multiple matching incidents. sys_ids: #{sys_ids.join(', ')}"
    end

    incidents[0]
  end
  module_function :get_single_incident

  def delete_incident(sys_id)
    params = {
      'table' => 'incident',
      'sys_id' => sys_id,
    }

    servicenow_instance.run_bolt_task('servicenow_tasks::delete_record', params)
  end
  module_function :delete_incident

  def delete_incidents(query)
    get_incidents(query).each do |incident|
      delete_incident(incident['sys_id'])
    end
  end
  module_function :delete_incidents
end
