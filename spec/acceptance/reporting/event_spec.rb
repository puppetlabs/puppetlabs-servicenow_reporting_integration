require 'spec_helper_acceptance'

describe 'ServiceNow reporting: event management' do
  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      user: servicenow_config['user'],
      password: "Sensitive('#{servicenow_config['password']}')",
      skip_certificate_validation: Helpers.skip_cert_check?,
    }
  end

  let(:setup_manifest) do
    to_manifest(declare('Service', 'pe-puppetserver'), declare('class', 'servicenow_reporting_integration::event_management', params))
  end

  include_context 'event query setup'

  it 'sends a node_report event' do
    set_sitepp_content(declare('notify', 'foo'))
    trigger_puppet_run(server, acceptable_exit_codes: [2])
    event = Helpers.get_single_record('em_event', query)
    additional_info = JSON.parse(event['additional_info'])

    expect(event['source']).to eql('Puppet')
    expect(event['type']).to eql('node_report_intentional_changes')
    expect(event['severity']).to eql('5')
    expect(event['message_key']).not_to be_empty
    expect(event['node']).not_to be_empty
    expect(event['event_class']).to match(Regexp.new(Regexp.escape(server.uri)))
    expect(event['description']).to match(Regexp.new(Regexp.escape(server.uri)))
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
    expect(additional_info['corrective_changes'].to_json).should_not be_nil
    expect(additional_info['pending_corrective_changes'].to_json).should_not be_nil
    expect(additional_info['intentional_changes'].to_json).should_not be_nil
    expect(additional_info['pending_intentional_changes'].to_json).should_not be_nil
    expect(additional_info['failures'].to_json).should_not be_nil
    # Check that the PE console URL is included
    expect(event['description']).to match(Regexp.new(Regexp.escape(server.uri)))
  end

  it 'handles a catalog failure properly' do
    set_sitepp_content("notify {'foo")
    trigger_puppet_run(server, acceptable_exit_codes: [1])
    set_sitepp_content('')
    event = Helpers.get_single_record('em_event', query)

    expect(event['description']).to match(%r{Report Labels:[\s\S]*catalog_failure})
    expect(event['description']).to match(%r{Log Output:})
    expect(event['type']).to eql('node_report_failed')
  end

  context 'when disabled' do
    let(:params) { super().merge('disabled' => true) }

    it 'does not send an event' do
      trigger_puppet_run(server, acceptable_exit_codes: [0, 2])
      expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    end
  end

  context 'when failures is enabled' do
    let(:params) { super().merge('event_creation_conditions' => ['failures']) }

    it 'sends an event when there is a failure' do
      # make sure site pp reflects a failure
      set_sitepp_content("notify {'foo")
      trigger_puppet_run(server, acceptable_exit_codes: [1])
      event = Helpers.get_single_record('em_event', query)
      expect(event['type']).to eql('node_report_failed')
    end

    it 'does not send on an intentional change' do
      set_sitepp_content(declare('notify', 'foo'))
      trigger_puppet_run(server, acceptable_exit_codes: [2])
      expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    end

    # context 'and puppet has corrective changes' do
    #   corr_hash = { 'type' => 'file', 'title' => '/tmp/corrective_change', 'params' => { 'content' => 'foo' } }
    #   include_context 'corrective change setup', corr_hash
    #   it 'does not send an event' do
    #     trigger_puppet_run(server, acceptable_exit_codes: [2])
    #     expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    #   end
    # end
  end

  context 'when never is enabled' do
    let(:params) { super().merge('event_creation_conditions' => ['never']) }

    it 'does not send an event' do
      trigger_puppet_run(server, acceptable_exit_codes: [0, 1, 2])
      expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    end
  end

  context 'when intentional change is enabled' do
    let(:params) { super().merge('event_creation_conditions' => ['intentional_changes']) }

    it 'sends an event on an intentional change' do
      set_sitepp_content(declare('notify', 'foo'))
      trigger_puppet_run(server, acceptable_exit_codes: [2])
      event = Helpers.get_single_record('em_event', query)
      expect(event['type']).to eql('node_report_intentional_changes')
    end

    it 'does not send an event on a failure' do
      # make sure site pp reflects a failure
      set_sitepp_content("notify {'foo")
      trigger_puppet_run(server, acceptable_exit_codes: [1])
      expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    end

    # context 'and puppet has corrective changes' do
    #   corr_hash = { 'type' => 'file', 'title' => '/tmp/corrective_change', 'params' => { 'content' => 'foo' } }
    #   include_context 'corrective change setup', corr_hash
    #   it 'does not send an event' do
    #     trigger_puppet_run(server, acceptable_exit_codes: [2])
    #     expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    #   end
    # end
  end

  context 'when corrective changes is enabled' do
    let(:params) { super().merge('event_creation_conditions' => ['corrective_changes']) }

    corr_hash = { 'type' => 'file', 'title' => '/tmp/corrective_change', 'params' => { 'content' => 'foo' } }
    include_context 'corrective change setup', corr_hash
    it 'sends an event on a correctional change' do
      trigger_puppet_run(server, acceptable_exit_codes: [2])
      event = Helpers.get_single_record('em_event', query)
      expect(event['type']).to eql('node_report_corrective_changes')
    end

    it 'does not send an event on intentional change' do
      set_sitepp_content(declare('notify', 'foo'))
      trigger_puppet_run(server, acceptable_exit_codes: [2])
      expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    end

    # it 'does not send an event when there is a failure' do
    #   # make sure site pp reflects a failure
    #   set_sitepp_content("notify {'foo")
    #   trigger_puppet_run(server, acceptable_exit_codes: [1])
    #   expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    # end
  end

  context 'when always is enabled' do
    let(:params) { super().merge('event_creation_conditions' => ['always']) }

    it 'sends an event when there is a failure' do
      # make sure site pp reflects a failure
      set_sitepp_content("notify {'foo")
      trigger_puppet_run(server, acceptable_exit_codes: [1])
      event = Helpers.get_single_record('em_event', query)
      expect(event['type']).to eql('node_report_failed')
    end

    it 'sends an event on an intentional change' do
      set_sitepp_content(declare('notify', 'foo'))
      trigger_puppet_run(server, acceptable_exit_codes: [2])
      event = Helpers.get_single_record('em_event', query)
      expect(event['type']).to eql('node_report_intentional_changes')
    end
  end

  context 'filters environment with allow_list and block_list' do
    context "when allow_list == ['all']" do
      let(:params) { super().merge('allow_list' => ['all']) }

      it 'always sends an event' do
        trigger_puppet_run(server, acceptable_exit_codes: [0, 1, 2])
        event = Helpers.get_single_record('em_event', query)
        expect(event['type']).not_to be_empty
      end
    end

    context "when allow_list == ['none'] and block_list == ['env_filter']" do
      let(:params) { super().merge('allow_list' => ['none'], 'block_list' => ['env_filter']) }

      it 'does not send an event' do
        trigger_puppet_run(server, acceptable_exit_codes: [0, 2])
        expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
      end
    end

    # context 'when allow_list matches environment' do
    #   let(:params) { super().merge('allow_list' => ['production']) }

    #   it 'sends an event' do
    #     trigger_puppet_run(server, acceptable_exit_codes: [0, 1, 2])
    #     event = Helpers.get_single_record('em_event', query)
    #     expect(event['type']).not_to be_empty
    #   end
    # end

    context 'when allow_list wildcard matches environment' do
      let(:params) { super().merge('allow_list' => ['prod*']) }

      it 'sends an event' do
        trigger_puppet_run(server, acceptable_exit_codes: [0, 1, 2])
        event = Helpers.get_single_record('em_event', query)
        expect(event['type']).not_to be_empty
      end
    end

    context "when block_list == ['all']" do
      let(:params) { super().merge('allow_list' => ['prod*'], 'block_list' => ['all']) }

      it 'does not send an event' do
        trigger_puppet_run(server, acceptable_exit_codes: [0, 2])
        expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
      end
    end

    # context 'when block_list matches environment' do
    #   let(:params) { super().merge('allow_list' => ['dev'], 'block_list' => ['production']) }

    #   it 'does not send an event' do
    #     trigger_puppet_run(server, acceptable_exit_codes: [0, 2])
    #     expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
    #   end
    # end

    context 'when block_list wildcard matches environment' do
      let(:params) { super().merge('allow_list' => ['dev'], 'block_list' => ['*tion', '*od']) }

      it 'does not send an event' do
        trigger_puppet_run(server, acceptable_exit_codes: [0, 2])
        expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
      end
    end

    context "when block_list and allow_list == ['none']" do
      let(:params) { super().merge('allow_list' => ['none'], 'block_list' => ['none']) }

      it 'does not send an event' do
        trigger_puppet_run(server, acceptable_exit_codes: [0, 2])
        expect { Helpers.get_single_record('em_event', query) }.to raise_error(%r{expected record matching query but none was found})
      end
    end
  end
end
