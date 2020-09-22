require 'json'
require 'spec_helper'
require 'support/unit/reports/shared_examples'

require 'puppet/reports'

def new_processor
  processor = Puppet::Transaction::Report.new('apply')
  processor.extend(Puppet::Reports.report(:servicenow))

  allow(processor).to receive(:time).and_return '00:00:00'
  allow(processor).to receive(:host).and_return 'host'
  allow(processor).to receive(:job_id).and_return '1'
  allow(processor).to receive(:time).and_return(Time.now)
  allow(processor).to receive(:metrics).and_return('time' => { 'total' => 0 })
  # The report processor logs all exceptions to Puppet.err. Thus, we mock it out
  # so that we can see them (and avoid false-positives).
  allow(Puppet).to receive(:err) do |msg|
    raise msg
  end

  processor
end

def default_settings_hash
  {
    'pe_console_url'                             => 'test_console',
    'caller'                                     => 'test_caller',
    'category'                                   => '1',
    'contact_type'                               => '1',
    'state'                                      => '1',
    'impact'                                     => '1',
    'urgency'                                    => '1',
    'assignment_group'                           => '1',
    'assigned_to'                                => '1',
    'instance'                                   => 'test_instance',
    'user'                                       => 'test_user',
    'password'                                   => 'test_password',
    'oauth_token'                                => 'test_token',
    'failures_event_severity'                    => 3,
    'corrective_changes_event_severity'          => 2,
    'intentional_changes_event_severity'         => 1,
    'pending_corrective_changes_event_severity'  => 2,
    'pending_intentional_changes_event_severity' => 1,
    'no_changes_event_severity'                  => 5000,
  }
end

def default_credentials
  {
    user: 'test_user',
    password: 'test_password',
  }
end

def mock_settings_file(settings_hash)
  allow(YAML).to receive(:load_file).with(%r{servicenow_reporting\.yaml}).and_return(settings_hash)
end

def new_mock_response(status, body)
  response = instance_double('mock HTTP response')
  allow(response).to receive(:code).and_return(status.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def new_mock_event(event_fields = {})
  event_fields[:property] = 'message'
  event_fields[:message]  = 'defined \'message\' as \'hello\''
  Puppet::Transaction::Event.new(event_fields)
end

def new_mock_resource_status(events, status_changed, status_failed)
  status = instance_double('resource status')
  allow(status).to receive(:events).and_return(events)
  allow(status).to receive(:out_of_sync).and_return(status_changed)
  allow(status).to receive(:failed).and_return(status_failed)
  allow(status).to receive(:containment_path).and_return(['foo', 'bar'])
  allow(status).to receive(:file).and_return('site.pp')
  allow(status).to receive(:line).and_return(1)
  status
end

def mock_events(processor, *events)
  allow(processor).to receive(:resource_statuses).and_return('mock_resource' => new_mock_resource_status(events, true, false))
end

def mock_event_as_resource_status(processor, event_status, event_corrective_change, status_changed = true, status_failed = false)
  mock_events = [new_mock_event(status: event_status, corrective_change: event_corrective_change)]
  mock_resource_status = new_mock_resource_status(mock_events, status_changed, status_failed)
  allow(processor).to receive(:resource_statuses).and_return('mock_resource' => mock_resource_status)
end

def expect_sent_event(expected_credentials = {})
  # do_snow_request will only be called to send an event
  expect(processor).to receive(:do_snow_request) do |_, _, request_body, actual_credentials|
    actual_events = request_body[:records]
    yield actual_events[0]
    expect(actual_credentials).to include(expected_credentials)
    new_mock_response(200, '')
  end
end

def collect_message_keys(*report_processors)
  report_processors.map do |processor|
    message_key = nil
    allow(processor).to receive(:do_snow_request) do |_, _, request_body, _|
      actual_events = request_body[:records]
      message_key = actual_events[0]['message_key']
      new_mock_response(200, '')
    end
    processor.process

    message_key
  end
end

def expect_created_incident(expected_incident, expected_credentials = {})
  # do_snow_request will only be called to create an incident
  expect(processor).to receive(:do_snow_request) do |_, _, actual_incident, actual_credentials|
    # Matching key-by-key makes it easier to debug test failures
    expect(actual_incident[:short_description]).to match(expected_incident[:short_description])

    expect(actual_incident[:description]).to match(expected_incident[:description])

    expect(actual_credentials).to include(expected_credentials)

    new_mock_response(200, { 'result' => { 'sys_id' => 'foo_sys_id', 'number' => 1 } }.to_json)
  end
end

def short_description_regex(status)
  # Since the formatted time string is regex only precise to the minute, the unit tests
  # execute fast enough that race conditions and intermittent failures shouldn't
  # be a problem.
  Regexp.new(%r{Puppet.*#{Regexp.escape(status)}.*#{processor.host} \(report time: #{Time.now.strftime('%F %H:%M')}.*\)})
end
