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
      'caller_id'      => 'foo_caller_id',
      'user'           => 'foo_user',
      'password'       => 'foo_password',
    }
  end
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
    let(:settings_file_path) { '/etc/puppetlabs/puppet/servicenow_reporting.yaml' }

    context 'when the checksum calculation fails' do
      before(:each) do
        allow(Puppet::Util::Checksums).to receive(:sha256_file).with(%r{reports.*servicenow}).and_raise('failed to access file')
      end

      it { is_expected.to compile.and_raise_error(%r{access.*file}) }
    end

    context 'when the module fails to access the settings file' do
      before(:each) do
        allow(Puppet::Util::Checksums).to receive(:sha256_file).with(%r{reports.*servicenow}).and_return('report_checksum')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_raise('failed to access file')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_checksum: report_checksum}) }
      it { is_expected.to contain_file(settings_file_path).that_notifies('Service[pe-puppetserver]') }
    end

    context 'when the stored checksum does not match the current checksum' do
      before(:each) do
        allow(Puppet::Util::Checksums).to receive(:sha256_file).with(%r{reports.*servicenow}).and_return('report_checksum')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_return('report_processor_checksum' => 'stored_checksum')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_checksum: report_checksum}) }
      it { is_expected.to contain_file(settings_file_path).that_notifies('Service[pe-puppetserver]') }
    end

    context 'when the stored checksum matches the current checksum' do
      before(:each) do
        allow(Puppet::Util::Checksums).to receive(:sha256_file).with(%r{reports.*servicenow}).and_return('report_checksum')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_return('report_processor_checksum' => 'report_checksum')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_checksum: report_checksum}) }
      it { is_expected.not_to contain_file(settings_file_path).that_notifies(['Service[pe-puppetserver]']) }
    end
  end
end
