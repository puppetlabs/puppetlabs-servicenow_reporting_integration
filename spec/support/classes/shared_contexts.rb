RSpec.shared_context 'common reporting integration setup' do
  let(:pre_condition) do
    <<-MANIFEST
    service { 'pe-puppetserver':
    }
    MANIFEST
  end
  let(:settings_file_path) { Puppet[:confdir] + '/servicenow_reporting.yaml' }
  # rspec-puppet caches the catalog in each test based on the params/facts.
  # However, some of the tests reuse the same params (like the report processor
  # tests). Thus to clear the cache, we have to reset the facts since the params
  # don't change.
  let(:facts) do
    # This is enough to reset the cache
    {
      '_cache_reset_' => SecureRandom.uuid,
    }
  end
end
