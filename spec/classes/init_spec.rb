# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

describe 'servicenow_reporting_integration' do
  let(:pre_condition) do
    <<-MANIFEST
    service { 'pe-puppetserver':
    }
    MANIFEST
  end

  let(:params) do
    {
      'instance'       => 'foo_instance',
      'pe_console_url' => 'foo_pe_console_url',
      'user'           => 'foo_user',
      'password'       => 'foo_password',
    }
  end
  let(:settings_file_path) { Puppet[:confdir] + '/servicenow_reporting.yaml' }
  # rspec-puppet caches the catalog in each test based on the params/facts.
  # However, some of the tests reuse the same params (like the report processor
  # tests). Thus to clear the cache, we have to reset the facts since the params
  # don't change.
  let(:facts) do
    # This is enough to reset the cache
    {
      '_cache_reset_' => SecureRandom.uuid,
    }
  end

  context 'when operation_mode == incident_management' do
    let(:params) do
      super().merge('operation_mode' => 'incident_management', 'caller_id' => 'foo_caller_id')
    end

    context 'without the required parameters' do
      let(:params) do
        p = super()
        p.delete('caller_id')
        p
      end

      it { is_expected.to compile.and_raise_error(%r{caller_id}) }
    end

    context 'without the optional parameters' do
      it { is_expected.to compile }
    end

    context 'with the optional parameters' do
      let(:params) do
        # ps => params
        ps = super()

        ps['category'] = 'foo_category'
        ps['subcategory'] = 'foo_subcategory'
        ps['contact_type'] = 'foo_contact_type'
        ps['state'] = 1
        ps['impact'] = 1
        ps['urgency'] = 1
        ps['assignment_group'] = 'foo_assignment_group'
        ps['assigned_to'] = 'foo_assigned_to'

        ps
      end

      it { is_expected.to compile }
    end
  end

  context 'with a user and password' do
    it { is_expected.to compile.with_all_deps }
  end

  context 'with an oauth_token' do
    let(:params) do
      super().merge('oauth_token' => 'foo_token')
             .tap { |hs| hs.delete('user') }
             .tap { |hs| hs.delete('password') }
    end

    it { is_expected.to compile }
  end

  context 'with all credentials' do
    let(:params) { super().merge('oauth_token' => 'foo_token') }

    it { is_expected.to compile.and_raise_error(%r{ please specify either user/password or oauth_token not both. }) }
  end

  context 'without any credentials' do
    let(:params) do
      super()
        .tap { |hs| hs.delete('user') }
        .tap { |hs| hs.delete('password') }
    end

    it { is_expected.to compile.and_raise_error(%r{ please specify either user/password or oauth_token }) }
  end

  context 'with only a user' do
    let(:params) { super().tap { |hs| hs.delete('password') } }

    it { is_expected.to compile.and_raise_error(%r{ missing password }) }
  end

  context 'with only a password' do
    let(:params) { super().tap { |hs| hs.delete('user') } }

    it { is_expected.to compile.and_raise_error(%r{ missing user }) }
  end

  context 'checking the report processor for any changes' do
    before(:each) do
      # This handles cases when Puppet::FileSystem is called outside of our
      # module
      allow(Puppet::FileSystem).to receive(:read).and_call_original
    end

    context 'when the module fails to read the metadata.json file' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_raise('failed to access file')
      end

      it { is_expected.to compile.and_raise_error(%r{access.*file}) }
    end

    context 'when the module fails to access the settings file' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_return('{"version":"1"}')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_raise('failed to access file')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_version: 1}) }
      it { is_expected.to contain_file(settings_file_path).that_notifies('Service[pe-puppetserver]') }
    end

    context 'when the stored version does not match the current version' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_return('{"version":"1"}')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_return('report_processor_version' => '2')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_version: 1}) }
      it { is_expected.to contain_file(settings_file_path).that_notifies('Service[pe-puppetserver]') }
    end

    context 'when the stored version matches the current version' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_return('{"version":"1"}')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_return('report_processor_version' => '1')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_version: 1}) }
      it { is_expected.not_to contain_file(settings_file_path).that_notifies(['Service[pe-puppetserver]']) }
    end
  end

  context 'settings file validation' do
    context 'operation_mode == event_management' do
      it { is_expected.to contain_file(settings_file_path).with_validate_cmd(%r{em_event}) }
    end

    context 'operation_mode == incident_management' do
      let(:params) do
        super().merge('operation_mode' => 'incident_management', 'caller_id' => 'foo_caller_id')
      end

      it { is_expected.to contain_file(settings_file_path).with_validate_cmd(%r{incident}) }
    end

    context 'user-specified servicenow_credentials_validation_table' do
      let(:params) do
        super().merge('servicenow_credentials_validation_table' => 'foo_validation_table')
      end

      it { is_expected.to contain_file(settings_file_path).with_validate_cmd(%r{foo_validation_table}) }
    end
  end
end
