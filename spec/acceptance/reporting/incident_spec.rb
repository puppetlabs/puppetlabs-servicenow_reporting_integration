# rubocop:disable Metrics/LineLength

require 'spec_helper_acceptance'

describe 'ServiceNow reporting: incident creation' do
  # Make this a top-level variable instead of a 'let' to avoid redundant
  # computation. Note that the kaller 'let' variable is necessary for the
  # example groups.
  kaller_record = begin
    task_params = {
      'table' => 'sys_user',
      'url_params' => {
        'sysparm_limit' => 1,
      },
    }
    users = servicenow_instance.run_bolt_task('servicenow_tasks::get_records', task_params).result['result']
    if users.empty?
      raise "cannot calculate the caller_id: there are no users available on the ServiceNow instance #{servicenow_instance.uri} (table sys_user)"
    end
    users[0]
  end

  let(:kaller) { kaller_record }
  let(:params) do
    servicenow_config = servicenow_instance.bolt_config['remote']

    {
      instance: servicenow_instance.uri,
      pe_console_url: "https://#{master.uri}",
      caller_id: kaller['sys_id'],
      user: servicenow_config['user'],
      password: servicenow_config['password'],
    }
  end
  let(:setup_manifest) do
    to_manifest(declare('Service', 'pe-puppetserver'), declare('class', 'servicenow_reporting_integration::incident_management', params))
  end
  let(:sitepp_content) do
    # This is test-specific
    ''
  end

  context 'with default incident_creation_conditions' do
    include_examples 'ictc', report_label: 'failures'
    include_examples 'ictc', report_label: 'corrective_changes'
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "with user-specified incident creation conditions (every non-default condition _except_ 'always')" do
    let(:params) do
      super().merge('incident_creation_conditions' => ['intentional_changes', 'pending_corrective_changes', 'pending_intentional_changes'])
    end

    include_examples 'ictc', report_label: 'intentional_changes'
    include_examples 'ictc', report_label: 'pending_intentional_changes'
    include_examples 'ictc', report_label: 'pending_corrective_changes'
    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  context "when the incident creation condition includes the 'always' condition" do
    let(:params) do
      super().merge('incident_creation_conditions' => ['always'])
    end

    include_examples 'ictc', report_label: 'failures'
    include_examples 'ictc', report_label: 'corrective_changes'
    include_examples 'ictc', report_label: 'intentional_changes'
    include_examples 'ictc', report_label: 'pending_intentional_changes'
    include_examples 'ictc', report_label: 'pending_corrective_changes'
    include_examples 'ictc', report_label: 'no_changes'
  end

  context "when incident_creation_conditions == ['never']" do
    let(:params) do
      super().merge('incident_creation_conditions' => ['never'])
    end

    include_examples 'ictc', report_label: 'failures', noop_test: true
    include_examples 'ictc', report_label: 'corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_intentional_changes', noop_test: true
    include_examples 'ictc', report_label: 'pending_corrective_changes', noop_test: true
    include_examples 'ictc', report_label: 'no_changes', noop_test: true
  end

  # This is testing a bugfix from a previous module version
  context 'distinguishing intentional changes from corrective changes' do
    context "incident creation conditions include 'intentional_changes' but not 'corrective_changes'" do
      let(:params) do
        super().merge('incident_creation_conditions' => ['intentional_changes'])
      end

      context 'report with intentional and corrective changes' do
        # cc => corrective change
        cc_resource_hash = { 'type' => 'file', 'title' => '/tmp/corrective_change', 'params' => { 'content' => 'foo' } }

        let(:sitepp_content) do
          to_manifest(
            to_declaration(cc_resource_hash),
            declare('notify', 'foo_intentional_change'),
          )
        end

        include_context 'corrective change setup', cc_resource_hash
        include_context 'incident query setup'
        include_examples 'incident creation test', 'changed' do
          let(:additional_incident_assertions) do
            # Testing to ensure that two resource statuses made it into the
            # description
            ->(incident) {
              # The header should only be in there once.
              header_count = incident['description'].scan(%r{Resource Statuses:}).size
              expect(header_count).to be(1)
              expect(incident['description']).to match(%r{File\[\/tmp\/corrective_change\]\/content:})
              expect(incident['description']).to match(%r{site.pp:2})
              expect(incident['description']).to match(%r{Notify\[foo_intentional_change\]\/message:})
              expect(incident['description']).to match(%r{site.pp:6})
              expect(incident['description']).to match(%r{Environment: production})
              expect(incident['description']).to match(%r{Report Labels:})
              expect(incident['description']).to match(%r{corrective_changes})
              expect(incident['description']).to match(%r{intentional_changes})
            }
          end
        end
      end
    end
  end

  context 'user specifies the remaining incident fields' do
    # Make this a top-level variable instead of a 'let' to avoid redundant
    # computation. Note that the ug_pair 'let' variable is necessary for the
    # example groups.
    ug_pair_record = begin
      task_params = {
        'table' => 'sys_user_grmember',
        'url_params' => {
          'sysparm_exclude_reference_link' => true,
        },
      }
      pairs = servicenow_instance.run_bolt_task('servicenow_tasks::get_records', task_params).result['result']
      if pairs.empty?
        raise "cannot calculate the ug_pair: there are no pairs available on the ServiceNow instance #{servicenow_instance.uri} (table sys_user_grmember)"
      end

      pair = pairs.find do |p|
        # We choose a different user so we can properly test the 'assigned_to' parameter
        p['user'] != kaller_record['name']
      end
      unless pair
        raise "cannot calculate the ug_pair: there are no pairs available on the ServiceNow instance #{servicenow_instance.uri} (table sys_user_grmember) s.t. pair['user'] != #{kaller['name']} (the calculated caller)"
      end

      pair
    end

    let(:ug_pair) { ug_pair_record }
    let(:params) do
      # ps => params
      ps = super().merge('incident_creation_conditions' => ['intentional_changes'])

      ps['category'] = 'software'
      ps['subcategory'] = 'os'
      ps['contact_type'] = 'email'
      ps['state'] = 8
      ps['impact'] = 1
      ps['urgency'] = 2
      ps['assignment_group'] = pair['group']
      ps['assigned_to'] = pair['user']

      ps
    end
    # Use a 'changed' report to test this
    let(:sitepp_content) do
      to_manifest(declare('notify', 'foo'))
    end

    include_context 'incident query setup'
    include_examples 'incident creation test', 'changed' do
      let(:additional_incident_assertions) do
        ->(incident) {
          expect(incident['category']).to eql('software')
          expect(incident['subcategory']).to eql('os')
          expect(incident['contact_type']).to eql('email')

          # Even though these are Integer fields on a real ServiceNow instance,
          # the table API still returns them as strings. However, the mock
          # ServiceNow instance returns them as integers to keep the mocking
          # simple. Thus, we just do a quick 'to_i' conversion so that these
          # assertions pass on both a real ServiceNow instance and on the mock
          # ServiceNow instance.
          expect(incident['state'].to_i).to be(8)
          expect(incident['impact'].to_i).to be(1)
          expect(incident['urgency'].to_i).to be(2)

          expect(incident['assignment_group']).to eql(ug_pair['group'])
          expect(incident['assigned_to']).to eql(ug_pair['user'])
        }
      end
    end
  end
end
