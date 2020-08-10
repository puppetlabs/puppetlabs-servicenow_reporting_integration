require 'json'

def new_mock_response(status, body)
  response = instance_double('mock HTTP response')
  allow(response).to receive(:code).and_return(status.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def new_mock_event(status, corrective_change)
  event = instance_double('resource event')
  allow(event).to receive(:status).and_return(status)
  allow(event).to receive(:corrective_change).and_return(corrective_change)
  event
end

def new_mock_resource_status(events)
  status = instance_double('resource status')
  allow(status).to receive(:events).and_return(events)
  status
end

def mock_event_as_resource_status(processor, event_status, event_corrective_change)
  mock_events = [new_mock_event(event_status, event_corrective_change)]
  mock_resource_status = new_mock_resource_status(mock_events)
  allow(processor).to receive(:resource_statuses).and_return('mock_resource' => mock_resource_status)
end

def expect_created_incident(expected_incident, expected_credentials = {})
  # do_snow_request will only be called to create an incident
  expect(processor).to receive(:do_snow_request) do |_, _, actual_incident, actual_credentials|
    # Matching key-by-key makes it easier to debug test failures
    expect(actual_incident[:short_description]).to match(expected_incident[:short_description])

    expect(actual_credentials).to include(expected_credentials)

    new_mock_response(200, { 'result' => { 'sys_id' => 'foo_sys_id', 'number' => 1 } }.to_json)
  end
end

def short_description_regex(status)
  Regexp.new("Puppet.*#{processor.time}.*#{Regexp.escape(status)}.*#{processor.host}")
end
