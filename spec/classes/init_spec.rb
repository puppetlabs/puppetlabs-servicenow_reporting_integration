# frozen_string_literal: true

require 'spec_helper'

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
      'user'           => 'foo_user',
      'password'       => 'foo_password',
      'pe_console_url' => 'foo_pe_console_url',
    }
  end

  it { is_expected.to compile }
end
