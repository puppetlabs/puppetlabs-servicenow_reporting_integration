def servicenow_params(args)
  args.names.map do |name|
    args[name] || ENV[name.to_s.upcase]
  end
end

namespace :acceptance do
  require 'puppet_litmus/rake_tasks'
  require_relative '../spec/support/acceptance/helpers'
  include TargetHelpers

  desc 'Provisions the VMs. This is currently just the server'
  task :provision_vms do
    if File.exist?('../spec/fixtures/litmus_inventory.yaml')
    # Check if a server VM's already been setup
      begin
        uri = server.uri
        puts("A server VM at '#{uri}' has already been set up")
        next
      rescue TargetNotFoundError
      # Pass-thru, this means that we haven't set up the server VM
      end
    end

    provision_list = ENV['PROVISION_LIST'] || 'acceptance'
    Rake::Task['litmus:provision_list'].invoke(provision_list)
  end

  # TODO: This should be refactored to use the https://github.com/puppetlabs/puppetlabs-peadm
  # module for PE setup
  desc 'Sets up PE on the server'
  task :setup_pe do
    include ::BoltSpec::Run
    inventory_hash = inventory_hash_from_inventory_file
    target_nodes = find_targets(inventory_hash, 'ssh_nodes')

    config = { 'modulepath' => File.join(Dir.pwd, 'spec', 'fixtures', 'modules') }

    bolt_result = run_plan('servicenow_reporting_integration::acceptance::pe_server_setup', {}, config: config, inventory: inventory_hash.clone)
  end

  desc 'Sets up the ServiceNow instance'
  task :setup_servicenow_instance, [:sn_instance, :sn_user, :sn_password, :sn_token] do |_, args|
    instance, user, password, token = servicenow_params(args)
    if instance.nil?
      # Start the mock ServiceNow instance. If an instance has already been started,
      # then the script will remove the old instance before replacing it with the new
      # one.
      puts("Starting the mock ServiceNow instance at the server (#{server.uri})")
      server.bolt_upload_file('spec/support/acceptance/servicenow', '/tmp/servicenow')
      puts server.bolt_run_script('spec/support/acceptance/start_mock_servicenow_instance.sh').stdout
      instance, user, password, token = "#{server.uri}:8000", 'mock_user', 'mock_password', 'mock_token'
    else
      # User provided their own ServiceNow instance so make sure that they've also
      # included the instance's credentials
      # Oauth tests will be skipped if a token is not provided.
      raise 'The ServiceNow username must be provided' if user.nil?
      raise 'The ServiceNow password must be provided' if password.nil?
      puts "oauth token not provided so the oauth token tests will be skipped" if token.nil?
    end

    # Update the inventory file
    puts('Updating the inventory.yaml file with the ServiceNow instance credentials')
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    servicenow_group = inventory_hash['groups'].find { |g| g['name'] =~ %r{servicenow} }
    unless servicenow_group
      servicenow_group = { 'name' => 'servicenow_nodes' }
      inventory_hash['groups'].push(servicenow_group)
    end
    servicenow_group['targets'] = [{
      'uri' => 'localhost:8000',
      'config' => {
        'transport' => 'remote',
        'remote' => {
          'user' => user,
          'password' => password,
          'oauth_token' => token,
        }
      },
      'facts' => {
        'platform' => 'servicenow',
        'provisioner' => 'docker',
        'container_name' => 'mock_servicenow_instance',
      },
      'vars' => {
        'role' => 'servicenow_instance',
      }
    }]
    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Installs the module on the server'
  task :install_module do
    Rake::Task['litmus:install_module'].invoke(server.uri)
  end

  desc 'Reloads puppetserver on the server'
  task :reload_module do
    result = server.run_shell('/opt/puppetlabs/bin/puppetserver reload').stdout.chomp
    puts "Error: #{result}" unless result.nil?
  end

  desc 'Gets the puppetserver logs for service now'
  task :get_logs do
    puts server.run_shell('tail -500 /var/log/puppetlabs/puppetserver/puppetserver.log').stdout.chomp
  end

  desc 'Do an agent run'
  task :agent_run do
    puts server.run_shell('puppet agent -t').stdout.chomp
  end

  desc 'Runs the tests'
  task :run_tests do
    rspec_command  = 'bundle exec rspec ./spec/acceptance --format documentation'
    rspec_command += ' --format RspecJunitFormatter --out rspec_junit_results.xml' if ENV['CI'] == 'true'
    puts("Running the tests ...\n")
    unless system(rspec_command)
      # system returned false which means rspec failed. So exit 1 here
      exit 1
    end
  end

  desc 'Set up the test infrastructure'
  task :setup do
    tasks = [
      :provision_vms,
      :setup_pe,
      :setup_servicenow_instance,
      :install_module,
    ]

    tasks.each do |task|
      task = "acceptance:#{task}"
      puts("Invoking #{task}")
      Rake::Task[task].invoke
      puts("")
    end
  end

  desc 'Teardown the setup'
  task :tear_down do
    puts("Tearing down the test infrastructure ...\n")
    Rake::Task['litmus:tear_down'].invoke(server.uri)
    FileUtils.rm_f('spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Task for CI'
  task :ci_run_tests do
    begin
      Rake::Task['acceptance:setup'].invoke
      Rake::Task['acceptance:run_tests'].invoke
    ensure
      Rake::Task['acceptance:tear_down'].invoke
    end
  end
end