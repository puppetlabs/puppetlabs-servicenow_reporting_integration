require 'support/unit/reports/servicenow_spec_helpers'

describe 'ServiceNow report processor: event_management mode' do
  let(:processor) { new_processor }
  let(:settings_hash) { default_settings_hash.merge('operation_mode' => 'event_management') }
  let(:expected_credentials) { default_credentials }

  before(:each) do
    mock_settings_file(settings_hash)
  end

  it 'sends a node_report event' do
    allow(processor).to receive(:status).and_return 'changed'
    allow(processor).to receive(:host).and_return 'fqdn'
    mock_event_as_resource_status(processor, 'success', false)

    expect_sent_event(expected_credentials) do |actual_event|
      expect(actual_event['source']).to eql('Puppet')
      expect(actual_event['type']).to eql('node_report')
      expect(actual_event['severity']).to eql('5')
      expect(actual_event['node']).to eql('fqdn')
      # The message key will be tested more thoroughly in other
      # tests
      expect(actual_event['message_key']).not_to be_empty
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
              mock_events(processor, new_mock_event(status: 'success', corrective_change: false))
            end
          end

          include_examples 'same message key'
        end

        context 'same status and same events but events are in a different order' do
          before(:each) do
            [processor_one, processor_two].each do |processor|
              allow(processor).to receive(:status).and_return('changed')
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
        end
      end

      include_examples 'different message key'
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
