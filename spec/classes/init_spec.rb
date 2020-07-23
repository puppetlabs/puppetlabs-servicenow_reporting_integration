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
      'caller_id'      => 'foo_caller_id',
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
end
