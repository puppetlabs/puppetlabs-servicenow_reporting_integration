require 'spec_helper_acceptance'

describe 'ServiceNow reporting' do
  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      user: servicenow_config['user'],
      password: servicenow_config['password'],
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

  before(:each) do
    # Set up the ServiceNow reporting integration
    master.apply_manifest(setup_manifest, catch_failures: true)
    # Set up the site.pp file
    set_sitepp_content(sitepp_content)
  end
  after(:each) do
    set_sitepp_content('')
  end

  it 'has idempotent setup' do
    master.idempotent_apply(setup_manifest)
  end

  shared_context 'incident creation test setup' do
    let(:query) do
      # This filters all report-processor generated incidents in descending
      # order, meaning incidents[0] is the most recently created incident
      'short_descriptionLIKEPuppet^ORDERBYDESCsys_created_on'
    end

    before(:each) do
      IncidentHelpers.delete_incidents(query)
    end
    after(:each) do
      IncidentHelpers.delete_incidents(query)
    end
  end

  context 'with report status: unchanged' do
    context 'and noop_pending: false' do
      let(:sitepp_content) do
        # Puppet should report that nothing happens
        ''
      end

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

      it 'creates an incident' do
        trigger_puppet_run(master, acceptable_exit_codes: [0])
        incident = IncidentHelpers.get_single_incident(query)
        expect(incident['short_description']).to match(%r{pending changes})
      end
    end
  end

  context 'with report status: changed' do
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    include_context 'incident creation test setup'

    it 'creates an incident' do
      trigger_puppet_run(master, acceptable_exit_codes: [2])
      incident = IncidentHelpers.get_single_incident(query)
      expect(incident['short_description']).to match(%r{changed})
    end
  end

  context 'with report status: failed' do
    let(:sitepp_content) do
      to_manifest(declare('exec', 'foo', 'command' => '/bin/foo_command'))
    end

    include_context 'incident creation test setup'

    it 'creates an incident' do
      trigger_puppet_run(master, acceptable_exit_codes: [1, 4, 6])
      incident = IncidentHelpers.get_single_incident(query)
      expect(incident['short_description']).to match(%r{failed})
    end
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

    it 'still works' do
      trigger_puppet_run(master, acceptable_exit_codes: [2])
      incident = IncidentHelpers.get_single_incident(query)
      expect(incident['short_description']).to match(%r{changed})
    end
  end
end
