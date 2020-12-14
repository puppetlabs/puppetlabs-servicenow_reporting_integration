# frozen_string_literal: true

require 'spec_helper'
require 'support/classes/shared_contexts'
require 'support/unit/sensitive'

describe 'servicenow_reporting_integration' do
  include_context 'common reporting integration setup'

  let(:params) do
    {
      'instance'                                => 'foo_instance',
      'pe_console_url'                          => 'foo_pe_console_url/',
      'user'                                    => 'foo_user',
      'password'                                => RSpec::Puppet::Sensitive.new('foo_password'),
      'operation_mode'                          => 'event_management',
      'servicenow_credentials_validation_table' => 'em_event',
    }
  end

  let(:file_resource_title) do
    # rspec-puppet tries its best to work with both Windows and Linux, but it
    # ends up with strange behavior in the $settings::confdir setting such that
    # it is not consistent when running on Linux and Windows. This function
    # is here to make sure the tests aren't broken due to the inconsistencies.
    # "#{Dir.pwd.gsub('\\','/')}/servicenow_reporting.yaml"

    "#{Dir.pwd.tr('\\', '/')}/servicenow_reporting.yaml"
  end

  it { is_expected.to compile }
  it { is_expected.to contain_file(file_resource_title).with_content %r{^pe_console_url: foo_pe_console_url$} }

  context 'consule url does not have a trialing slash' do
    let(:params) do
      super().merge('pe_console_url' => 'foo_pe_console_url')
    end

    it { is_expected.to contain_file(file_resource_title).with_content %r{^pe_console_url: foo_pe_console_url$} }
  end
end
