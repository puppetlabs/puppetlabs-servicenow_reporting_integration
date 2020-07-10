require 'json'

def new_mock_response(status, body)
  response = instance_double('mock HTTP response')
  allow(response).to receive(:code).and_return(status.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def expect_created_incident(credentials = {})
  # do_snow_request will only be called to create an incident
  expect(processor).to receive(:do_snow_request)
    .with(anything, anything, anything, hash_including(credentials))
    .and_return(new_mock_response(200, { 'sys_id' => 'foo_sys_id' }.to_json))
end
