require 'json'

def new_mock_response(status, body)
  response = instance_double('mock HTTP response')
  allow(response).to receive(:code).and_return(status.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def expect_created_incident(expected_incident, expected_credentials = {})
  # do_snow_request will only be called to create an incident
  expect(processor).to receive(:do_snow_request) do |_, _, actual_incident, actual_credentials|
    expect(actual_incident).to include(short_description: match(expected_incident[:short_description]))
    expect(actual_credentials).to include(expected_credentials)

    new_mock_response(200, { 'result' => { 'sys_id' => 'foo_sys_id', 'number' => 1 } }.to_json)
  end
end

def short_description_regex(status)
  Regexp.new("Puppet.*#{processor.time}.*#{Regexp.escape(status)}.*#{processor.host}")
end
