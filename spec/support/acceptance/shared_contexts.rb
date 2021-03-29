RSpec.shared_context 'reporting test setup' do
  before(:each) do
    # Set up the ServiceNow reporting integration
    master.apply_manifest(setup_manifest, catch_failures: true)
    # Set up the site.pp file
    set_sitepp_content(sitepp_content)
  end
  after(:each) do
    set_sitepp_content('')
  end
end

RSpec.shared_context 'incident query setup' do
  include_context 'reporting test setup'

  let(:query) do
    # This filters all report-processor generated incidents in descending
    # order, meaning incidents[0] is the most recently created incident
    'short_descriptionLIKEPuppet^ORDERBYDESCsys_created_on'
  end

  before(:each) do
    Helpers.delete_records('incident', query)
  end
  after(:each) do
    Helpers.delete_records('incident', query)
  end
end

RSpec.shared_context 'event query setup' do
  before(:each) do
    # Set up the ServiceNow reporting integration
    master.apply_manifest(setup_manifest, catch_failures: true)
  end

  let(:query) do
    # This filters all report-processor generated events in descending
    # order, meaning events[0] is the most recently created event
    'sourceLIKEPuppet^ORDERBYDESCtime_of_event'
  end

  before(:each) do
    Helpers.delete_records('em_event', query)
  end
  after(:each) do
    Helpers.delete_records('em_event', query)
  end
end

# NOTE: The incident query setup also cleans any dangling ServiceNow instances and
# sets up the master's site.pp for the incident tests. Thus, make sure to place this
# _before_ the incident query setup so that the latter's postconditions are still
# maintained (like the master's expected site.pp).
RSpec.shared_context 'corrective change setup' do |file_resource_hash|
  before(:each) do
    # Ensure that noop is false (possible if we are setting up a pending corrective
    # change)
    params = file_resource_hash['params'].merge('noop' => false)
    file_resource_hash = file_resource_hash.merge('params' => params)

    # For a change to be considered corrective, the resource needs to be managed
    # and in the correct state at least one time, and then a drift from that
    # state corrected. This setup manages a file and then drifts its state. A simple
    # `puppet apply` (master.apply_manifest) won't work because that won't write anything
    # to the puppetserver's history of what has and has not been managed in the past (where
    # the past history is used to calculate corrective changes). Only `puppet agent -t` will
    # do that.
    set_sitepp_content(to_manifest(to_declaration(file_resource_hash)))
    trigger_puppet_run(master)
    master.write_file("#{file_resource_hash['params']['content']}_corrective_change_setup", file_resource_hash['title'])
  end
end
