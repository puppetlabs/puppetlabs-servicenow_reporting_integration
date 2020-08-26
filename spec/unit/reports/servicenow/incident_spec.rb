require 'support/unit/reports/servicenow_spec_helpers'

describe 'ServiceNow report processor: incident creation' do
  let(:processor) { new_processor }
  let(:settings_hash) { default_settings_hash }
  let(:expected_credentials) { default_credentials }
  let(:facts) { default_facts }

  before(:each) do
    mock_settings_file(settings_hash)
    allow(processor).to receive(:facts).and_return(facts)
  end

  context 'when incident_creation_conditions is not an array' do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => 'not_an_array')
    end

    it 'raises an error' do
      expect { processor.process }.to raise_error(RuntimeError, %r{not_an_array})
    end
  end

  # These tests test that each of the incident creation condition enums do the 'right'
  # thing, specifically that they do/don't create an incident for different kinds of
  # reports

  context "when 'failures' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['failures'])
    end

    include_examples 'ictc', report_label: 'failures'
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'corrective_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['corrective_changes'])
    end

    include_examples 'ictc', report_label: 'corrective_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'intentional_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['intentional_changes'])
    end

    include_examples 'ictc', report_label: 'intentional_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'pending_corrective_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['pending_corrective_changes'])
    end

    include_examples 'ictc', report_label: 'pending_corrective_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'pending_intentional_changes' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['pending_intentional_changes'])
    end

    include_examples 'ictc', report_label: 'pending_intentional_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when 'always' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['always'])
    end

    include_examples 'ictc', report_label: 'failures'
    include_examples 'ictc', report_label: 'corrective_changes'
    include_examples 'ictc', report_label: 'intentional_changes'
    include_examples 'ictc', report_label: 'pending_corrective_changes'
    include_examples 'ictc', report_label: 'pending_intentional_changes'
    include_examples 'ictc', report_label: 'no_changes'
  end

  context "when 'never' is enabled" do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['never'])
    end

    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "report has an 'audit' event" do
    let(:settings_hash) do
      # Choose an arbitrary 'event' condition here to ensure that the event-looping
      # logic is triggered
      super().merge('incident_creation_conditions' => ['corrective_changes'])
    end

    before(:each) do
      mock_event_as_resource_status(processor, 'audit', false)
    end

    it 'still works' do
      expect(processor).not_to receive(:do_snow_request)
      results = processor.process
      # If the report processor returns false we know that the process
      # method was exited early.
      expect(results).to be false
    end
  end

  context 'receiving response code greater than 200' do
    let(:settings_hash) do
      super().merge('incident_creation_conditions' => ['failures'])
    end

    it 'returns the response code from Servicenow' do
      allow(processor).to receive(:status).and_return 'failed'

      [300, 400, 500].each do |response_code|
        allow(processor).to receive(:do_snow_request).and_return(new_mock_response(response_code, { 'sys_id' => 'foo_sys_id' }.to_json))
        expect { processor.process }.to raise_error(RuntimeError, %r{(status: #{response_code})})
      end
    end
  end
end
