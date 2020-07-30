require 'spec_helper_acceptance'
require 'securerandom'
# rubocop:disable Metrics/LineLength

describe 'ServiceNow reporting' do
  # Make this a top-level variable instead of a 'let' to avoid redundant
  # computation. Note that the kaller 'let' variable is necessary for the
  # example groups.
  kaller_record = begin
    task_params = {
      'table' => 'sys_user',
      'url_params' => {
        'sysparm_limit' => 1,
      },
    }
    users = servicenow_instance.run_bolt_task('servicenow_tasks::get_records', task_params).result['result']
    if users.empty?
      raise "cannot calculate the caller_id: there are no users available on the ServiceNow instance #{servicenow_instance.uri} (table sys_user)"
    end
    users[0]
  end

  let(:kaller) { kaller_record }
  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      user: servicenow_config['user'],
      password: servicenow_config['password'],
      pe_console_url: "https://#{master.uri}",
      caller_id: kaller['sys_id'],
    }
  end
  let(:setup_manifest) do
    to_manifest(declare('Service', 'pe-puppetserver'), declare('class', 'servicenow_reporting_integration', params))
  end
  let(:sitepp_content) do
    # This is test-specific
    ''
  end

  before(:all) do
    # Some of the tests require an 'unchanged' Puppet run so they use an 'unchanged' site.pp manifest
    # to simulate this scenario. However, our 'unchanged' Puppet run will still include the default
    # PE classes _on top_ of our site.pp manifest. Some of these classes trigger changes whenever we
    # update the reporting module for the tests. To prevent those changes from happening _while_ running
    # the tests, we do a quick Puppet run _before_ all the tests to enact the PE module-specific changes.
    # This way, all of our tests begin with a 'clean' Puppet slate.
    trigger_puppet_run(master)
  end

  it 'has idempotent setup' do
    clear_reporting_integration_setup
    master.idempotent_apply(setup_manifest)
  end

  context 'with report status: unchanged' do
    context 'and noop_pending: false' do
      let(:sitepp_content) do
        # Puppet should report that nothing happens
        ''
      end

      include_context 'reporting test setup'

      it 'does nothing' do
        num_incidents_before_puppet_run = IncidentHelpers.get_incidents('').length
        trigger_puppet_run(master, acceptable_exit_codes: [0])
        num_incidents_after_puppet_run = IncidentHelpers.get_incidents('').length
        expect(num_incidents_after_puppet_run).to eql(num_incidents_before_puppet_run)
      end
    end

    context 'and noop_pending: true' do
      let(:sitepp_content) do
        to_manifest(declare('notify', 'foo', 'noop' => true))
      end

      include_context 'incident creation test setup'
      include_examples 'incident creation test', 'noop_pending'
    end
  end

  context 'with report status: changed' do
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    include_context 'incident creation test setup'
    include_examples 'incident creation test', 'changed'
  end

  context 'with report status: failed' do
    let(:sitepp_content) do
      to_manifest(declare('exec', 'foo', 'command' => '/bin/foo_command'))
    end

    include_context 'incident creation test setup'
    include_examples 'incident creation test', 'failed'
  end

  context 'user specifies a hiera-eyaml encrypted password' do
    let(:params) do
      default_params = super()
      password = default_params.delete(:password)
      default_params[:password] = master.run_shell("/opt/puppetlabs/puppet/bin/eyaml encrypt -s #{password} -o string").stdout
      default_params
    end
    # Use a 'changed' report to test this.
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    include_context 'incident creation test setup'
    include_examples 'incident creation test', 'changed'
  end

  context 'user specifies the remaining incident fields' do
    # Make this a top-level variable instead of a 'let' to avoid redundant
    # computation. Note that the ug_pair 'let' variable is necessary for the
    # example groups.
    ug_pair_record = begin
      task_params = {
        'table' => 'sys_user_grmember',
        'url_params' => {
          'sysparm_exclude_reference_link' => true,
        },
      }
      pairs = servicenow_instance.run_bolt_task('servicenow_tasks::get_records', task_params).result['result']
      if pairs.empty?
        raise "cannot calculate the ug_pair: there are no pairs available on the ServiceNow instance #{servicenow_instance.uri} (table sys_user_grmember)"
      end

      pair = pairs.find do |p|
        # We choose a different user so we can properly test the 'assigned_to' parameter
        p['user'] != kaller_record['name']
      end
      unless pair
        raise "cannot calculate the ug_pair: there are no pairs available on the ServiceNow instance #{servicenow_instance.uri} (table sys_user_grmember) s.t. pair['user'] != #{kaller['name']} (the calculated caller)"
      end

      pair
    end

    let(:ug_pair) { ug_pair_record }
    let(:params) do
      # ps => params
      ps = super()

      ps['category'] = 'software'
      ps['subcategory'] = 'os'
      ps['contact_type'] = 'email'
      ps['state'] = 8
      ps['impact'] = 1
      ps['urgency'] = 2
      ps['assignment_group'] = pair['group']
      ps['assigned_to'] = pair['user']

      ps
    end
    # Use a 'changed' report to test this
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    include_context 'incident creation test setup'
    include_examples 'incident creation test', 'changed' do
      let(:additional_incident_assertions) do
        ->(incident) {
          expect(incident['category']).to eql('software')
          expect(incident['subcategory']).to eql('os')
          expect(incident['contact_type']).to eql('email')

          # Even though these are Integer fields on a real ServiceNow instance,
          # the table API still returns them as strings. However, the mock
          # ServiceNow instance returns them as integers to keep the mocking
          # simple. Thus, we just do a quick 'to_i' conversion so that these
          # assertions pass on both a real ServiceNow instance and on the mock
          # ServiceNow instance.
          expect(incident['state'].to_i).to be(8)
          expect(incident['impact'].to_i).to be(1)
          expect(incident['urgency'].to_i).to be(2)

          expect(incident['assignment_group']).to eql(ug_pair['group'])
          expect(incident['assigned_to']).to eql(ug_pair['user'])
        }
      end
    end
  end

  context 'when the report processor changes between module versions' do
    # In this test, we'll replace the module's report processor with a 'stub'
    # report processor that creates a 'report_processed' file. We'll then
    # trigger a puppet run and afterwards assert that our 'report_processed'
    # file was created.
    let(:created_file_path) do
      basename = File.basename(Tempfile.new('report_processed'))
      "/tmp/#{basename}"
    end
    let(:report_processor_implementation) do
      <<-CODE
      Puppet::Reports.register_report(:servicenow) do
        def process
          Puppet::FileSystem.touch("#{created_file_path}")
        end
      end
      CODE
    end
    let(:reports_dir) do
      '/etc/puppetlabs/code/environments/production/modules/servicenow_reporting_integration/lib/puppet/reports'
    end

    include_context 'reporting test setup'

    before(:each) do
      master.run_shell("rm -f #{created_file_path}")
      master.run_shell("mv #{reports_dir}/servicenow.rb #{reports_dir}/servicenow_current.rb")
      write_file(master, "#{reports_dir}/servicenow.rb", report_processor_implementation)
    end
    after(:each) do
      master.run_shell("rm -f #{created_file_path}")
      master.run_shell("mv #{reports_dir}/servicenow_current.rb #{reports_dir}/servicenow.rb")
    end

    it 'picks up those changes' do
      master.apply_manifest(setup_manifest, catch_failures: true)
      trigger_puppet_run(master, acceptable_exit_codes: [0])
      begin
        master.run_shell("ls #{created_file_path}")
      rescue => e
        raise "failed to assert that #{created_file_path} was created: #{e}"
      end
    end
  end

  context 'settings file validation' do
    before(:each) do
      clear_reporting_integration_setup
    end

    context 'invalid PE console url' do
      let(:params) do
        default_params = super()
        default_params[:pe_console_url] = 'invalid_url'
        default_params
      end

      include_examples 'settings file validation failure'
    end

    context 'invalid ServiceNow credentials' do
      let(:params) do
        default_params = super()
        default_params[:user] = "invalid_#{default_params[:user]}"
        default_params
      end

      include_examples 'settings file validation failure'
    end

    context 'user wants to skip ServiceNow credentials validation' do
      let(:params) do
        default_params = super()
        default_params[:servicenow_credentials_validation_table] = ''
        # Provide invalid credentials on purpose to make sure that the ServiceNow credentials
        # validation is actually skipped
        default_params[:user] = "invalid_#{default_params[:user]}"
        default_params
      end

      it 'can still setup the reporting integration' do
        master.apply_manifest(setup_manifest, catch_failures: true)
        reports_setting = master.run_shell('puppet config print reports --section master').stdout.chomp
        expect(reports_setting).to match(%r{servicenow})
      end
    end
  end
end
