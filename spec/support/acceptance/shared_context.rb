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

RSpec.shared_context 'incident creation test setup' do
  include_context 'reporting test setup'

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
