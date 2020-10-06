require 'support/unit/reports/servicenow_spec_helpers'

describe 'ServiceNow report processor: event_management mode' do
  let(:processor) { new_processor }
  let(:settings_hash) { default_settings_hash.merge('operation_mode' => 'event_management') }
  let(:expected_credentials) { default_credentials }
  let(:facts) { default_facts }

  before(:each) do
    mock_settings_file(settings_hash)
    allow(processor).to receive(:facts).and_return(facts)
  end

  it 'sends a node_report event' do
    allow(processor).to receive(:status).and_return 'changed'
    allow(processor).to receive(:host).and_return 'fqdn'
    mock_event_as_resource_status(processor, 'success', false)

    expect_sent_event(expected_credentials) do |actual_event|
      additional_info = JSON.parse(actual_event['additional_info'])
      expect(actual_event['source']).to eql('Puppet')
      expect(actual_event['type']).to eql('node_report_changed')
      expect(actual_event['severity']).to eql('1')
      expect(actual_event['node']).to eql('fqdn')
      expect(actual_event['description']).to match(%r{test_console})
      expect(actual_event['description']).to match(%r{Resource Statuses:\s\/foo\/bar\/message: defined 'message' as 'hello'})
      expect(actual_event['description']).to match(%r{Resource Definition: site.pp:1})
      expect(actual_event['description']).to match(%r{Environment: production})
      expect(actual_event['description']).to match(%r{== Facts ==})
      expect(actual_event['description']).to match(%r{id: foo})
      expect(actual_event['description']).to match(%r{os.distro:\s+codename:[\s\S]*description})
      expect(actual_event['description']).to match(%r{Report Labels:[\s\S]*intentional_changes})
      expect(additional_info['id']).to eql('foo')
      expect(additional_info['environment']).to eql('production')
      expect(additional_info['ipaddress']).to eql('192.168.0.1')
      expect(additional_info['os.distro']['codename']).to eql('xenial')
      # The message key will be tested more thoroughly in other
      # tests
      expect(actual_event['message_key']).not_to be_empty
    end

    processor.process
  end

  it 'sends a node_report with no resource events' do
    allow(processor).to receive(:status).and_return 'changed'
    allow(processor).to receive(:host).and_return 'fqdn'
    mock_event_as_resource_status(processor, 'success', false, false)

    expect_sent_event(expected_credentials) do |actual_event|
      expect(actual_event['source']).to eql('Puppet')
      expect(actual_event['type']).to eql('node_report_changed')
      expect(actual_event['severity']).to eql('1')
      expect(actual_event['node']).to eql('fqdn')
      expect(actual_event['description']).to match(%r{test_console})
      expect(actual_event['description']).not_to match(%r{Resource Statuses:})
      # The message key will be tested more thoroughly in other
      # tests
      expect(actual_event['message_key']).not_to be_empty
    end

    processor.process
  end

  it 'sends a node_report_failure' do
    allow(processor).to receive(:status).and_return 'failure'
    allow(processor).to receive(:host).and_return 'fqdn'
    mock_event_as_resource_status(processor, 'failure', false, false)

    expect_sent_event(expected_credentials) do |actual_event|
      expect(actual_event['source']).to eql('Puppet')
      expect(actual_event['type']).to eql('node_report_failure')
      expect(actual_event['severity']).to eql('3')
      expect(actual_event['node']).to eql('fqdn')
      expect(actual_event['description']).to match(%r{test_console})
      expect(actual_event['description']).not_to match(%r{Resource Statuses:})
      # The message key will be tested more thoroughly in other
      # tests
      expect(actual_event['message_key']).not_to be_empty
    end

    processor.process
  end

  it 'sends a node_report_unchanged' do
    allow(processor).to receive(:status).and_return 'unchanged'
    allow(processor).to receive(:host).and_return 'fqdn'
    mock_event_as_resource_status(processor, 'success', false, false)

    expect_sent_event(expected_credentials) do |actual_event|
      additional_info = JSON.parse(actual_event['additional_info'])

      expect(actual_event['source']).to eql('Puppet')
      expect(actual_event['type']).to eql('node_report_unchanged')
      expect(actual_event['severity']).to eql('1')
      expect(actual_event['node']).to eql('fqdn')
      expect(actual_event['description']).to match(%r{test_console})
      expect(actual_event['description']).not_to match(%r{Resource Statuses:})
      expect(additional_info['id']).to eql('foo')
      expect(additional_info['environment']).to eql('production')
      expect(additional_info['ipaddress']).to eql('192.168.0.1')
      expect(additional_info['os.distro']['codename']).to eql('xenial')
      # The message key will be tested more thoroughly in other
      # tests
      expect(actual_event['message_key']).not_to be_empty
    end

    processor.process
  end

  it 'includes multiple labels in a description' do
    events = [new_mock_event(status: 'success', corrective_change: true), new_mock_event(status: 'failure')]
    mock_resource_statuses = new_mock_resource_status(events, true, true)
    allow(processor).to receive(:resource_statuses).and_return('mock_resource' => mock_resource_statuses)

    expect_sent_event(expected_credentials) do |actual_event|
      expect(actual_event['description']).to match(%r{Report Labels:})
      expect(actual_event['description']).to match(%r{failures})
      expect(actual_event['description']).to match(%r{corrective_changes})
    end

    processor.process
  end

  context 'testing the message_key' do
    context 'same node, two reports' do
      let(:processor_one) { new_processor }
      let(:processor_two) { new_processor }

      context 'identical reports' do
        context 'same status and same events' do
          before(:each) do
            [processor_one, processor_two].each do |processor|
              allow(processor).to receive(:status).and_return('changed')
              allow(processor).to receive(:facts).and_return(facts)
              mock_events(processor, new_mock_event(status: 'success', corrective_change: false))
            end
          end

          include_examples 'same message key'
        end

        context 'same status and same events but events are in a different order' do
          before(:each) do
            [processor_one, processor_two].each do |processor|
              allow(processor).to receive(:status).and_return('changed')
              allow(processor).to receive(:facts).and_return(facts)
            end

            events = [
              new_mock_event(status: 'failure'),
              new_mock_event(status: 'success', corrective_change: false),
            ]
            mock_events(processor_one, *events)
            mock_events(processor_two, *events.reverse)
          end

          include_examples 'same message key'
        end
      end

      context 'different reports' do
        context 'different status, same events' do
          before(:each) do
            [processor_one, processor_two].each do |processor|
              mock_events(processor, new_mock_event(status: 'failure'))
              allow(processor).to receive(:facts).and_return(facts)
            end

            allow(processor_one).to receive(:status).and_return('failed')
            allow(processor_two).to receive(:status).and_return('changed')
          end

          include_examples 'different message key'
        end

        context 'same status, different events' do
          before(:each) do
            [processor_one, processor_two].each do |processor|
              allow(processor).to receive(:status).and_return('changed')
              allow(processor).to receive(:facts).and_return(facts)
            end

            mock_events(processor_one, new_mock_event(status: 'failure'))
            mock_events(processor_two, new_mock_event(status: 'success'))
          end

          include_examples 'different message key'
        end
      end
    end

    context 'different node, same reports' do
      let(:processor_one) { new_processor }
      let(:processor_two) { new_processor }

      before(:each) do
        allow(processor_one).to receive(:host).and_return('node_one')
        allow(processor_two).to receive(:host).and_return('node_two')

        [processor_one, processor_two].each do |processor|
          mock_events(processor)
          allow(processor).to receive(:facts).and_return(facts)
        end
      end

      include_examples 'different message key'
    end
  end

  context 'sends the appropriate event severity' do
    examples = [{ status: 'failure', event_corrective_change: false, expected_severity: '3',    status_changed: true,  status_failed: false },
                { status: 'success', event_corrective_change: true,  expected_severity: '2',    status_changed: true,  status_failed: false },
                { status: 'noop',    event_corrective_change: true,  expected_severity: '2',    status_changed: true,  status_failed: false },
                { status: 'success', event_corrective_change: false, expected_severity: '1',    status_changed: true,  status_failed: false },
                { status: 'noop',    event_corrective_change: false, expected_severity: '1',    status_changed: true,  status_failed: false },
                { status: 'audit',   event_corrective_change: false, expected_severity: '5000', status_changed: false, status_failed: false }]

    examples.each do |example|
      include_examples 'event severity levels', example
    end
  end

  context 'receiving response code greater than 200' do
    it 'returns the response code from Servicenow' do
      allow(processor).to receive(:status).and_return 'failed'
      mock_event_as_resource_status(processor, 'success', false)

      [300, 400, 500].each do |response_code|
        allow(processor).to receive(:do_snow_request).and_return(new_mock_response(response_code, ''))
        expect { processor.process }.to raise_error(RuntimeError, %r{(status: #{response_code})})
      end
    end
  end
end
