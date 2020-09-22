require 'support/unit/reports/servicenow_spec_helpers'
# rubocop:disable RSpec/ScatteredSetup

RSpec.shared_examples 'incident creation test' do |report_status|
  it 'creates an incident' do
    expected_short_description = case report_status.to_s
                                 when 'pending'
                                   %r{pending changes}
                                 when 'unchanged'
                                   %r{unchanged}
                                 when 'changed'
                                   %r{changed}
                                 when 'failed'
                                   %r{failed}
                                 else
                                   raise "invalid report_status #{report_status}. Valid report statuses are 'noop_pending', 'changed', 'failed'"
                                 end

    expected_description = %r{#{settings_hash['pe_console_url']}}

    expected_incident = {
      short_description: expected_short_description,
      description: expected_description,
    }
    expect_created_incident(expected_incident, expected_credentials)

    processor.process
  end
end

RSpec.shared_examples 'no incident' do
  it 'does not create an incident' do
    expect(processor).not_to receive(:do_snow_request)
    results = processor.process
    # If the report processor returns false we know that the process
    # method was exited early.
    expect(results).to be false
  end
end

# 'ictc' => 'incident creation test case'
RSpec.shared_examples 'ictc' do |report_label: nil, noop_test: false|
  context "report with #{report_label}" do
    expected_report_status =
      # Setup the processor then return the expected report status
      case report_label
      when 'failures'
        before(:each) do
          allow(processor).to receive(:status).and_return('failed')
        end

        'failed'
      when 'corrective_changes'
        before(:each) do
          allow(processor).to receive(:status).and_return('changed')
          mock_event_as_resource_status(processor, 'success', true)
        end

        'changed'
      when 'intentional_changes'
        before(:each) do
          allow(processor).to receive(:status).and_return('changed')
          mock_event_as_resource_status(processor, 'success', false)
        end

        'changed'
      when 'pending_corrective_changes'
        before(:each) do
          allow(processor).to receive(:status).and_return('unchanged')
          allow(processor).to receive(:noop_pending).and_return(true)
          mock_event_as_resource_status(processor, 'noop', true)
        end

        'pending'
      when 'pending_intentional_changes'
        before(:each) do
          allow(processor).to receive(:status).and_return('unchanged')
          allow(processor).to receive(:noop_pending).and_return(true)
          mock_event_as_resource_status(processor, 'noop', false)
        end

        'pending'
      when 'no_changes'
        before(:each) do
          allow(processor).to receive(:status).and_return('unchanged')
          allow(processor).to receive(:noop_pending).and_return(false)
        end

        'unchanged'
      else
        raise "unknown report_label: #{report_label}"
      end

    # Include the relevant test
    if noop_test
      include_examples 'no incident'
    else
      include_examples 'incident creation test', expected_report_status
    end
  end
end

RSpec.shared_examples 'same message key' do
  it 'calculates the same message key for the ServiceNow events' do
    message_keys = collect_message_keys(processor_one, processor_two)
    expect(message_keys[0]).to eql(message_keys[1])
  end
end

RSpec.shared_examples 'different message key' do
  it 'calculates different message keys for the ServiceNow events' do
    message_keys = collect_message_keys(processor_one, processor_two)
    expect(message_keys[0]).not_to eql(message_keys[1])
  end
end

RSpec.shared_examples 'event severity levels' do |status: 'success', event_corrective_change: true, expected_severity: '1', status_changed: true, status_failed: false|
  it "sends the appropriate event severity for status: #{status} and event corrective_change: #{event_corrective_change}" do
    mock_event_as_resource_status(processor, status, event_corrective_change, status_changed, status_failed)

    expect_sent_event(expected_credentials) do |actual_event|
      expect(actual_event['severity']).to eql(expected_severity.to_s)
    end

    processor.process
  end
end
