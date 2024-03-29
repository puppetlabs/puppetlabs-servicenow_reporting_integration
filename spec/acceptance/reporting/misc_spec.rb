require 'spec_helper_acceptance'

describe 'ServiceNow reporting: miscellaneous tests' do
  # Stub out the caller
  let(:kaller) do
    {
      'sys_id' => 'foo',
    }
  end

  let(:fqdn) do
    server.run_shell('facter fqdn').stdout.chomp
  end

  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      pe_console_url: "https://#{fqdn}",
      caller_id: kaller['sys_id'],
      user: servicenow_config['user'],
      password: "Sensitive('#{servicenow_config['password']}')",
      skip_certificate_validation: true,
      pe_console_cert_validation: 'none',
    }
  end
  let(:setup_manifest) do
    to_manifest(declare('Service', 'pe-puppetserver'), declare('class', 'servicenow_reporting_integration::incident_management', params))
  end
  let(:sitepp_content) do
    # This is test-specific
    ''
  end

  it 'has idempotent setup' do
    clear_reporting_integration_setup
    server.idempotent_apply(setup_manifest)
  end

  context 'user specifies a hiera-eyaml encrypted password' do
    let(:params) do
      servicenow_config = servicenow_instance.bolt_config['remote']
      default_params = super().merge('incident_creation_conditions' => ['intentional_changes'])
      password = servicenow_config['password']
      encrypted_password = server.run_shell("/opt/puppetlabs/puppet/bin/eyaml encrypt -s #{password} -o string").stdout
      default_params[:password] = "Sensitive('#{encrypted_password.chomp}')"
      default_params
    end
    # Use a 'changed' report to test this.
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    include_context 'incident query setup'
    include_examples 'incident creation test', 'changed'
  end

  context 'user specifies a hiera-eyaml encrypted oauth token' do
    # skip the oauth tests if we don't have an oauth token to test with
    servicenow_config = servicenow_instance.bolt_config['remote']
    skip_oauth_tests = false
    using_mock_instance = servicenow_instance.uri =~ Regexp.new(Regexp.escape(server.run_shell('facter fqdn').stdout.chomp))
    unless using_mock_instance
      skip_oauth_tests = (servicenow_config['oauth_token']) ? false : true
    end

    puts 'Skipping this test because there is no token specified in the test inventory.' if skip_oauth_tests

    let(:params) do
      default_params = super()
      default_params.delete(:user)
      default_params.delete(:password)
      oauth_token = servicenow_config['oauth_token']
      encryped_token = server.run_shell("/opt/puppetlabs/puppet/bin/eyaml encrypt -s #{oauth_token} -o string").stdout
      default_params[:oauth_token] = "Sensitive('#{encryped_token.chomp}')"
      default_params[:incident_creation_conditions] = ['intentional_changes']
      default_params
    end
    # Use a 'changed' report to test this.
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    unless skip_oauth_tests
      include_context 'incident query setup'
      include_examples 'incident creation test', 'changed'
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
    let(:old_metadata_json) do
      get_metadata_json
    end

    include_context 'reporting test setup'

    before(:each) do
      server.run_shell("rm -f #{created_file_path}")
      server.run_shell("mv #{reports_dir}/servicenow.rb #{reports_dir}/servicenow_current.rb")
      server.write_file(report_processor_implementation, "#{reports_dir}/servicenow.rb")

      # Update the metadata.json version to simulate a report processor change
      new_metadata_json = old_metadata_json.merge('version' => '0.0.0')
      server.write_file(JSON.pretty_generate(new_metadata_json), METADATA_JSON_PATH)
      server.run_shell("chown pe-puppet #{reports_dir}/servicenow.rb #{METADATA_JSON_PATH}")
    end

    after(:each) do
      server.run_shell("rm -f #{created_file_path}")
      server.run_shell("mv #{reports_dir}/servicenow_current.rb #{reports_dir}/servicenow.rb")
      server.write_file(JSON.pretty_generate(old_metadata_json), METADATA_JSON_PATH)
    end

    it 'picks up those changes' do
      server.apply_manifest(setup_manifest, catch_failures: true)
      trigger_puppet_run(server, acceptable_exit_codes: [0])
      begin
        server.run_shell("ls #{created_file_path}")
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
        server.apply_manifest(setup_manifest, catch_failures: true)
        reports_setting = server.run_shell('puppet config print reports --section server').stdout.chomp
        expect(reports_setting).to match(%r{servicenow})
      end
    end
  end

  # Servicenow_instance.uri has been set to localhost:8000 for testing purposes on the cloud.
  context 'module fails against servicenow container if cert validation on' do
    let(:params) do
      super().merge(skip_certificate_validation: false, incident_creation_conditions: ['always'])
    end

    it 'certificate validation fails' do
      server.apply_manifest(setup_manifest, expect_failures: true) do |failure|
        expect(failure['stderr']).to match(%r{failed to validate the ServiceNow credentials})
        expect(failure['stderr']).to match(%r{SSL_connect returned=1})
      end
    end
  end
end
