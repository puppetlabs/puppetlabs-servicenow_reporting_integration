require 'spec_helper_acceptance'

describe 'ServiceNow reporting: event management' do
  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      user: servicenow_config['user'],
      password: servicenow_config['password'],
      skip_certificate_validation: Helpers.skip_cert_check?,
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
    additional_info = JSON.parse(event['additional_info'])

    expect(event['source']).to eql('Puppet')
    expect(event['type']).to eql('node_report_changed')
    expect(event['severity']).to eql('5')
    expect(event['message_key']).not_to be_empty
    expect(event['node']).not_to be_empty
    expect(event['event_class']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(event['description']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(event['description']).to match(%r{Environment: production})
    expect(event['description']).to match(%r{Resource Statuses:})
    expect(event['description']).to match(%r{Environment: production})
    expect(event['description']).to match(%r{Notify\[foo\]\/message: defined 'message' as 'foo'})
    expect(event['description']).to match(%r{manifests\/site.pp:2})
    expect(event['description']).to match(%r{== Facts ==})
    expect(event['description']).to match(%r{id: root})
    expect(event['description']).to match(%r{os.distro:\s+codename:[\s\S]*description})
    expect(additional_info['environment']).to eql('production')
    expect(additional_info['id']).to eql('root')
    expect(additional_info['ipaddress']).to match(%r{^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$})
    expect(additional_info['os.distro']['codename']).not_to be_empty
    expect(additional_info['report_labels']).to eql('intentional_changes')
    # Check that the PE console URL is included
    expect(event['description']).to match(Regexp.new(Regexp.escape(master.uri)))
  end

  it 'handles a catalog failure properly' do
    set_sitepp_content("notify {'foo")
    trigger_puppet_run(master, acceptable_exit_codes: [1])
    set_sitepp_content('')
    event = Helpers.get_single_record('em_event', query)

    expect(event['description']).to match(%r{Report Labels:[\s\S]*catalog_failure})
    expect(event['description']).to match(%r{Log Output:})
    expect(event['type']).to eql('node_report_failed')
  end

  context 'when disabled' do
    let(:params) { super().merge('disabled' => true) }

    it 'does not send an event' do
      trigger_puppet_run(master, acceptable_exit_codes: [0, 2])
      expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    end
  end
end
