# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'support/classes/shared_contexts'
require 'support/classes/shared_examples'
require 'support/unit/sensitive'

describe 'servicenow_reporting_integration::event_management' do
  include_context 'common reporting integration setup'

  let(:params) do
    {
      'instance'       => 'foo_instance',
      'pe_console_url' => 'foo_pe_console_url',
      'user'           => 'foo_user',
      'password'       => RSpec::Puppet::Sensitive.new('foo_password'),
    }
  end

  it { is_expected.to compile }

  include_examples 'common reporting integration tests', operation_mode: 'event_management'
end
