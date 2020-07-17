RSpec.shared_examples 'incident creation test' do |report_status|
  it 'creates an incident' do
    puppet_exit_codes, expected_short_description = case report_status.to_s
                                                    when 'noop_pending'
                                                      [[0], %r{pending changes}]
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
  end
end
