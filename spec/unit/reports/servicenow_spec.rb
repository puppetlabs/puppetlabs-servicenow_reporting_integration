# rubocop:disable Metrics/LineLength

require 'spec_helper'
require 'support/unit/reports/servicenow_spec_helpers'
require 'support/unit/reports/shared_examples'

require 'puppet/reports'

describe 'ServiceNow report processor' do
  let(:processor) do
    processor = Puppet::Transaction::Report.new('apply')
    processor.extend(Puppet::Reports.report(:servicenow))
    allow(processor).to receive(:time).and_return '00:00:00'
    allow(processor).to receive(:host).and_return 'host'
    allow(processor).to receive(:job_id).and_return '1'
    allow(processor).to receive(:time).and_return(Time.now)
    allow(processor).to receive(:metrics).and_return('time' => { 'total' => 0 })
    processor
  end

  let(:settings_hash) do
    { 'pe_console_url'   => 'test_console',
      'caller'           => 'test_caller',
      'category'         => '1',
      'contact_type'     => '1',
      'state'            => '1',
      'impact'           => '1',
      'urgency'          => '1',
      'assignment_group' => '1',
      'assigned_to'      => '1',
      'instance'         => 'test_instance',
      'user'             => 'test_user',
      'password'         => 'test_password',
      'oauth_token'      => 'test_token' }
  end
  let(:expected_credentials) do
    {
      user: 'test_user',
      password: 'test_password',
    }
  end

  before(:each) do
    # The report processor logs all exceptions to Puppet.err. Thus, we mock it out
    # so that we can see them (and avoid false-positives).
    allow(Puppet).to receive(:err) do |msg|
      raise msg
    end

    # Mock the settings hash
    allow(YAML).to receive(:load_file).with(%r{servicenow_reporting\.yaml}).and_return(settings_hash)
  end

  context 'when incident_creation_conditions is not an array' do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => 'not_an_array')
    end

    it 'raises an error' do
      expect { processor.process }.to raise_error(RuntimeError, %r{not_an_array})
    end
  end

  # These tests test that each of the incident creation condition enums do the 'right'
  # thing, specifically that they do/don't create an incident for different kinds of
  # reports

  context "when 'failures' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['failures'])
    end

    include_examples 'ictc', report_label: 'failures'
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'corrective_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['corrective_changes'])
    end

    include_examples 'ictc', report_label: 'corrective_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'intentional_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['intentional_changes'])
    end

    include_examples 'ictc', report_label: 'intentional_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'pending_corrective_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['pending_corrective_changes'])
    end

    include_examples 'ictc', report_label: 'pending_corrective_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'pending_intentional_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['pending_intentional_changes'])
    end

    include_examples 'ictc', report_label: 'pending_intentional_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'always' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['always'])
    end

    include_examples 'ictc', report_label: 'failures'
    include_examples 'ictc', report_label: 'corrective_changes'
    include_examples 'ictc', report_label: 'intentional_changes'
    include_examples 'ictc', report_label: 'pending_corrective_changes'
    include_examples 'ictc', report_label: 'pending_intentional_changes'
    include_examples 'ictc', report_label: 'no_changes'
  end

  context "when 'never' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['never'])
    end

    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "report has an 'audit' event" do
    let(:settings_hash) do
      # Choose an arbitrary 'event' condition here to ensure that the event-looping
      # logic is triggered
      super().merge('incident_creation_conditions' => ['corrective_changes'])
    end

    before(:each) do
      mock_event_as_resource_status(processor, 'audit', false)
    end

    it 'still works' do
      expect(processor).not_to receive(:do_snow_request)
      results = processor.process
      # If the report processor returns false we know that the process
      # method was exited early.
      expect(results).to be false
    end
  end

  context 'receiving response code greater than 200' do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['failures'])
    end

    it 'returns the response code from Servicenow' do
      allow(processor).to receive(:status).and_return 'failed'

      [300, 400, 500].each do |response_code|
        allow(processor).to receive(:do_snow_request).and_return(new_mock_response(response_code, { 'sys_id' => 'foo_sys_id' }.to_json))
        expect { processor.process }.to raise_error(RuntimeError, %r{(status: #{response_code})})
      end
    end
  end

  context 'loading ServiceNow config' do
    shared_context 'setup hiera-eyaml' do
      before(:each) do
        # Choose an arbitrary incident-creation status
        allow(processor).to receive(:status).and_return 'failed'

        hiera_eyaml_config = {
          pkcs7_private_key: File.absolute_path('./spec/support/common/hiera-eyaml/private_key.pkcs7.pem'),
          pkcs7_public_key: File.absolute_path('./spec/support/common/hiera-eyaml/public_key.pkcs7.pem'),
        }
        # These are what hiera-eyaml's load_config_file method delegates to so we mock them to also
        # test that we're calling the right "load hiera-eyaml config" method
        allow(File).to receive(:file?).and_call_original
        allow(File).to receive(:file?).with('/etc/eyaml/config.yaml').and_return(true)
        allow(YAML).to receive(:load_file).with('/etc/eyaml/config.yaml').and_return(hiera_eyaml_config)
      end
    end

    context 'with hiera-eyaml encrypted password' do
      let(:encrypted_password) do
        # This will be set by the tests
        nil
      end
      let(:config) do
        default_config = super()
        # Note: This password is the encrypted form of 'test_password'. It was generated by the command
        # 'eyaml encrypt -s 'test_password' --pkcs7-private-key=./spec/support/common/hiera-eyaml/private_key.pkcs7.pem --pkcs7-public-key=./spec/support/common/hiera-eyaml/public_key.pkcs7.pem'
        default_config['password'] = encrypted_password
        default_config
      end

      include_context 'setup hiera-eyaml'

      context 'that contains whitespace characters' do
        let(:encrypted_password) do
          <<-PASSWORD
          ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw
          DQYJKoZIhvcNAQEBBQAEggEATRNhowHPKMCD2VrAgKz35BZLTG3Iuf34XfG2
          OUdwNw9IIEqHQiNXKbuqJa6T/6okGGtEVoSYMNk/jgTZS5IFMSZCIELNBcSo
          qS6ALwgPfyvmsVAzUpdfKIzuyszA4YczMGxUN3Plo5/1EHdzDZjtrEQ9QUHj
          jBlfOW95i5wKKwCzbAh5KshPyxwZ8cro9zHAzH7W4THDzWNwtn6523ZLrXll
          bxYYXfwGp3TBJJOvG+LsrdQUvbQOF+efgsgXRi/0e50kSByvUSBtEBkhm7vt
          DYvlL+0lfHjGk0+Trx9+VxMVb+kEW1P3R5ZC1K50fIflJxlueFsPazzLYcpS
          WjQB2zA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBBpjFMFKz7Y/7BtRzv5
          /TLngBBQBvBP5DV57A1iY/y2extG]
          PASSWORD
        end
        let(:settings_hash) do
          super().merge('incident_creation_conditions' => ['failures'])
        end

        it 'decrypts the password' do
          expected_incident = {
            short_description: short_description_regex('failed'),
          }
          expect_created_incident(expected_incident, expected_credentials)
          processor.process
        end
      end

      context 'that does not contain whitespace characters' do
        let(:encrypted_password) do
          'ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEwDQYJKoZIhvcNAQEBBQAEggEATRNhowHPKMCD2VrAgKz35BZLTG3Iuf34XfG2OUdwNw9IIEqHQiNXKbuqJa6T/6okGGtEVoSYMNk/jgTZS5IFMSZCIELNBcSoqS6ALwgPfyvmsVAzUpdfKIzuyszA4YczMGxUN3Plo5/1EHdzDZjtrEQ9QUHjjBlfOW95i5wKKwCzbAh5KshPyxwZ8cro9zHAzH7W4THDzWNwtn6523ZLrXllbxYYXfwGp3TBJJOvG+LsrdQUvbQOF+efgsgXRi/0e50kSByvUSBtEBkhm7vtDYvlL+0lfHjGk0+Trx9+VxMVb+kEW1P3R5ZC1K50fIflJxlueFsPazzLYcpSWjQB2zA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBBpjFMFKz7Y/7BtRzv5/TLngBBQBvBP5DV57A1iY/y2extG]'
        end
        let(:settings_hash) do
          super().merge('incident_creation_conditions' => ['failures'])
        end

        it 'decrypts the password' do
          expected_incident = {
            short_description: short_description_regex('failed'),
          }
          expect_created_incident(expected_incident, expected_credentials)
          processor.process
        end
      end
    end

    context 'with hiera-eyaml encrypted oauth_token' do
      # Note: This oauth_token is the encrypted form of 'oauth_token'. It was generated by the command
      # 'eyaml encrypt -s 'oauth_token' --pkcs7-private-key=./spec/support/files/private_key.pkcs7.pem --pkcs7-public-key=./spec/support/files/public_key.pkcs7.pem'
      let(:encrypted_oauth_token) do
        'ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEwDQYJKoZIhvcNAQEBBQAEggEAKVAUJvBJGrG25SGq0oVymzCxlQ3rvnqNHvl4rKagNshNDe0FKXUxDv0lz/DuklYMTFnKrm8gZxNESvr35ecBM2FckDy1NkIaWWKVFMg5H7KuZaCN/mFgtEpwUkUl3yJpcoJsfN4FpdCWAwjLF1qdOQ25nMEB9sKezZUKMjKm0pnGslr2Gj35HTTxc78HgT9cgVZHi5+NefFlMHDUZWyuSeL4xr4msUFDn6F1RoJp8zYPz31kBMgbowTNxICJV4vX8plwNgLcJicuqeOsEkznO/1bc+fh2yyiAUqimwctd20oni6eubkV8JY5wxfETX+GOiHuHCYZPFemTXHxl3O/GTA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBBl5Z3XF8s8RfEEGTDABqwDgBAadR7I9hBGLSC0m5Ut6xzo]'
      end
      let(:config) do
        default_config = super()
        default_config['oauth_token'] = encrypted_oauth_token
        default_config
      end
      let(:settings_hash) do
        super().merge('incident_creation_conditions' => ['failures'])
      end

      include_context 'setup hiera-eyaml'

      it 'decrypts the oauth token' do
        expected_incident = {
          short_description: short_description_regex('failed'),
        }
        expect_created_incident(expected_incident, oauth_token: 'test_token')
        processor.process
      end
    end
  end
end
