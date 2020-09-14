# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'support/classes/shared_contexts'
require 'support/classes/shared_examples'

describe 'servicenow_reporting_integration::incident_management' do
  include_context 'common reporting integration setup'

  let(:params) do
    {
      'instance'       => 'foo_instance',
      'pe_console_url' => 'foo_pe_console_url',
      'user'           => 'foo_user',
      'password'       => 'foo_password',
      'caller_id'      => 'foo_caller_id',
    }
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

  include_examples 'common reporting integration tests', operation_mode: 'incident_management'
end
