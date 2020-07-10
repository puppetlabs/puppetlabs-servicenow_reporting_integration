require 'spec_helper'

require 'puppet/reports'

servicenow = Puppet::Reports.report(:servicenow)

describe servicenow do
  let(:processor) do
    processor = Puppet::Transaction::Report.new('apply')
    processor.extend(Puppet::Reports.report(:servicenow))
    processor
  end

  let(:settings_hash) do
    { 'pe_console'       => 'test_console',
      'caller'           => 'test_caller',
      'category'         => '1',
      'contact_type'     => '1',
      'state'            => '1',
      'impact'           => '1',
      'urgency'          => '1',
      'assignment_group' => '1',
      'assigned_to'      => '1',
      'snow_instance'    => 'fake.service-now.com',
      'user'             => 'test_user',
      'password'         => 'test_password',
      'oauth_token'      => 'test_token' }
  end

  context 'with report status: unchanged' do
    context 'and noop_pending: false' do
      it 'does nothing' do
        allow(processor).to receive(:status).and_return 'unchanged'
        allow(processor).to receive(:noop_pending).and_return false

        results = processor.process
        # If the report processor returns false we know that the process
        # method was exited early.
        expect(results).to be false
        expect(processor).not_to receive(:do_snow_request)
      end
    end

    context 'and noop_pending: true' do
      it 'creates incident' do
        allow(processor).to receive(:status).and_return 'unchanged'
        allow(processor).to receive(:noop_pending).and_return true
        allow(processor).to receive(:time).and_return '00:00:00'
        allow(processor).to receive(:host).and_return 'host'
        allow(processor).to receive(:job_id).and_return '1'
        allow(processor).to receive(:settings).and_return(settings_hash)
        # do_snow_request will only be called to create an incident
        expect(processor).to receive(:do_snow_request)
        processor.process
      end
    end
  end

  context 'with report status: changed' do
    it 'creates incident' do
      allow(processor).to receive(:status).and_return 'changed'
      allow(processor).to receive(:time).and_return '00:00:00'
      allow(processor).to receive(:host).and_return 'host'
      allow(processor).to receive(:job_id).and_return '1'
      allow(processor).to receive(:settings).and_return(settings_hash)
      # do_snow_request will only be called to create an incident
      expect(processor).to receive(:do_snow_request)
      processor.process
    end
  end

  context 'with report status: failed' do
    it 'creates incident' do
      allow(processor).to receive(:status).and_return 'failed'
      allow(processor).to receive(:time).and_return '00:00:00'
      allow(processor).to receive(:host).and_return 'host'
      allow(processor).to receive(:job_id).and_return '1'
      allow(processor).to receive(:settings).and_return(settings_hash)
      # do_snow_request will only be called to create an incident
      expect(processor).to receive(:do_snow_request)
      processor.process
    end
  end
end
