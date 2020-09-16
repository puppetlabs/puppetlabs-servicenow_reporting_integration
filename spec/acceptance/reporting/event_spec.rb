require 'spec_helper_acceptance'

describe 'ServiceNow reporting: event management' do
  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      user: servicenow_config['user'],
      password: servicenow_config['password'],
    }
  end
  let(:setup_manifest) do
    to_manifest(declare('Service', 'pe-puppetserver'), declare('class', 'servicenow_reporting_integration::event_management', params))
  end

  include_context 'event query setup'

  it 'sends a node_report event' do
    set_sitepp_content(declare('notify', 'foo'))
    trigger_puppet_run(master, acceptable_exit_codes: [2])
    event = Helpers.get_single_record('em_event', query)
    expect(event['source']).to eql('Puppet')
    expect(event['type']).to eql('node_report')
    expect(event['severity']).to eql('1')
    expect(event['message_key']).not_to be_empty
    expect(event['node']).not_to be_empty
    expect(event['event_class']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(event['description']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(event['description']).to match(%r{Resource Statuses:})
    expect(event['description']).to match(%r{Notify\[foo\]\/message: defined 'message' as 'foo'})
    expect(event['description']).to match(%r{manifests\/site.pp:2})
    # Check that the PE console URL is included
    expect(event['description']).to match(Regexp.new(Regexp.escape(master.uri)))
  end
end
