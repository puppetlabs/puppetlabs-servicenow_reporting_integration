RSpec.shared_examples 'incident creation test' do |report_status, resource_hash|
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

    trigger_puppet_run(server, acceptable_exit_codes: puppet_exit_codes)
    incident = Helpers.get_single_record('incident', query)
    expect(incident['short_description']).to match(expected_short_description)
    expect(incident['description']).to match(Regexp.new(Regexp.escape(server.uri)))
    expect(incident['caller_id']).to eql(kaller['sys_id'])

    unless expected_short_description == %r{unchanged}
      expect(incident['description']).to match(%r{Resource Statuses:})
      expect(incident['description']).to match(resource_title_regex(resource_hash)) unless resource_hash.nil?
      expect(incident['description']).to match(%r{manifests\/site.pp:2})
    end

    if respond_to?(:additional_incident_assertions)
      additional_incident_assertions.call(incident)
    end
  end
end

RSpec.shared_examples 'settings file validation failure' do
  it 'reports an error and does not setup the report processor' do
    server.apply_manifest(setup_manifest, expect_failures: true)
    reports_setting = server.run_shell('puppet config print reports --section server').stdout.chomp
    expect(reports_setting).not_to match(%r{servicenow})
  end
end

RSpec.shared_examples 'no incident' do |report_status|
  it 'does not create an incident' do
    exit_codes = case report_status
                 when 'failed'
                   [1, 4, 6]
                 else
                   [0, 2]
                 end
    num_incidents_before_puppet_run = Helpers.get_records('incident', '').length
    trigger_puppet_run(server, acceptable_exit_codes: exit_codes)
    num_incidents_after_puppet_run = Helpers.get_records('incident', '').length
    expect(num_incidents_after_puppet_run).to eql(num_incidents_before_puppet_run)
  end
end

# 'ictc' => 'incident creation test case'
RSpec.shared_examples 'ictc' do |report_label: nil, noop_test: false|
  context "report with #{report_label}" do
    expected_report_status, resource_hash = case report_label
                                            when 'failures'
                                              ['failed', { 'type' => 'exec', 'title' => '/bin/foo_command' }]
                                            when 'corrective_changes'
                                              ['changed', { 'type' => 'file', 'title' => '/tmp/corrective_change', 'params' => { 'content' => 'foo' } }]
                                            when 'intentional_changes'
                                              ['changed', { 'type' => 'notify', 'title' => 'foo_intentional' }]
                                            when 'pending_corrective_changes'
                                              ['pending', { 'type' => 'file', 'title' => '/tmp/pending_corrective_change', 'params' => { 'content' => 'foo', 'noop' => true } }]
                                            when 'pending_intentional_changes'
                                              ['pending', { 'type' => 'notify', 'title' => 'foo_pending_intentional', 'params' => { 'noop' => true } }]
                                            when 'no_changes'
                                              ['unchanged', nil]
                                            else
                                              raise "unknown report_label: #{report_label}"
                                            end

    let(:sitepp_content) do
      resource_hash ? to_manifest(to_declaration(resource_hash)) : ''
    end

    # Include the setup
    if report_label.include?('corrective')
      include_context 'corrective change setup', resource_hash
    end
    include_context 'incident query setup'

    # Include the relevant test
    if noop_test
      include_examples 'no incident', expected_report_status
    else
      include_examples 'incident creation test', expected_report_status, resource_hash
    end
  end
end
