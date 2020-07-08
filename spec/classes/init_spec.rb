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
      'instance' => 'foo_instance',
      'user' => 'foo_user',
      'password' => 'foo_password',
    }
  end

  it { is_expected.to compile }

  context 'calculating the reports setting' do
    # rspec-puppet caches the catalog in each test based on the params/facts.
    # To clear the cache, we have to test each value in its own context block so
    # that we can properly reset the params/facts. Since the params shouldn't
    # change in each test, we'll be resetting the facts instead.
    values = {
      'none'                           => 'servicenow',
      'foo'                            => 'foo, servicenow',
      'foo, bar, baz'                  => 'foo, bar, baz, servicenow',
      '  foo  '                        => 'foo, servicenow',
      'foo  , bar  , baz'              => 'foo, bar, baz, servicenow',
      'servicenow'                     => 'servicenow',
      '  servicenow  '                 => '  servicenow  ',
      'foo, servicenow'                => 'foo, servicenow',
      '  foo, servicenow  '            => '  foo, servicenow  ',
      'foo  , bar  , baz,  servicenow' => 'foo  , bar  , baz,  servicenow',
      'foo, servicenow, bar'           => 'foo, servicenow, bar',
    }
    values.each do |value, expected_setting_value|
      context "when setting = '#{value}'" do
        let(:facts) do
          # This is enough to reset the facts
          {
            '_report_settings_value' => value,
          }
        end

        it do
          allow(Puppet).to receive(:[]).with(anything).and_call_original
          allow(Puppet).to receive(:[]).with(:reports).and_return(value)
          is_expected.to contain_ini_setting('puppetserver puppetconf add servicenow report processor').with_value(expected_setting_value)
        end
      end
    end
  end
end
