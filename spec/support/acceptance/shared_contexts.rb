
RSpec.shared_context 'incident query setup' do
  let(:query) do
    # This filters all report-processor generated incidents in descending
    # order, meaning incidents[0] is the most recently created incident
    'short_descriptionLIKEPuppet^ORDERBYDESCsys_created_on'
  end

  before(:each) do
    IncidentHelpers.delete_incidents(query)
  end
  after(:each) do
    IncidentHelpers.delete_incidents(query)
  end
end

RSpec.shared_context 'corrective change' do |noop = false|
  before(:each) do
    # For a change to be considered corrective, the resource needs to be managed and in
    # the correct state at least one time, and then a drift from that state corrected.
    # This setup manages a file and then drifts its state. The noop added to the
    # resource will still mark the report as noop_pending.
    set_sitepp_content(to_manifest(declare('file', '/tmp/test', 'content' => 'hello')))
    trigger_puppet_run(master)
    write_file(master, '/tmp/test', 'blah')

    if noop
      set_sitepp_content(declare('file', '/tmp/test', 'content' => 'hello', 'noop' => true))
    end
  end
end
