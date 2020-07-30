RSpec.shared_examples 'incident creation test' do |report_status|
  it 'creates an incident' do
    puppet_exit_codes, expected_short_description = case report_status.to_s
                                                    when 'pending'
                                                      [[0], %r{pending changes}]
                                                    when 'unchanged'
                                                      [[0], %r{unchanged}]
                                                    when 'changed'
                                                      [[2], %r{changed}]
                                                    when 'failed'
                                                      [[1, 4, 6], %r{failed}]
                                                    else
                                                      raise "invalid report_status #{report_status}. Valid report statuses are 'noop_pending', 'changed', 'failed'"
                                                    end

    trigger_puppet_run(master, acceptable_exit_codes: puppet_exit_codes)
    incident = IncidentHelpers.get_single_incident(query)
    expect(incident['short_description']).to match(expected_short_description)
    expect(incident['description']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(incident['caller_id']).to eql(kaller['sys_id'])
    if respond_to?(:additional_incident_assertions)
      additional_incident_assertions.call(incident)
    end
  end
end

RSpec.shared_examples 'settings file validation failure' do
  it 'reports an error and does not setup the report processor' do
    master.apply_manifest(setup_manifest, expect_failures: true)
    reports_setting = master.run_shell('puppet config print reports --section master').stdout.chomp
    expect(reports_setting).not_to match(%r{servicenow})
  end
end

RSpec.shared_examples 'no incident' do |expectation|
  it 'does not create an incident' do
    exit_codes = case expectation
                 when 'failure'
                   [1, 4, 6]
                 else
                   [0, 2]
                 end
    num_incidents_before_puppet_run = IncidentHelpers.get_incidents('').length
    trigger_puppet_run(master, acceptable_exit_codes: exit_codes)
    num_incidents_after_puppet_run = IncidentHelpers.get_incidents('').length
    expect(num_incidents_after_puppet_run).to eql(num_incidents_before_puppet_run)
  end
end
