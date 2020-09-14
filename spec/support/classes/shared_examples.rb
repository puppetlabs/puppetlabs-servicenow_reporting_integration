RSpec.shared_examples 'common reporting integration tests' do |operation_mode: nil|
  default_validation_table = case operation_mode
                             when 'incident_management'
                               'incident'
                             when 'event_management'
                               'em_event'
                             else
                               raise "invalid operation mode #{operation_mode}"
                             end

  context 'with a user and password' do
    it { is_expected.to compile.with_all_deps }
  end

  context 'with an oauth_token' do
    let(:params) do
      super().merge('oauth_token' => 'foo_token')
             .tap { |hs| hs.delete('user') }
             .tap { |hs| hs.delete('password') }
    end

    it { is_expected.to compile }
  end

  context 'with all credentials' do
    let(:params) { super().merge('oauth_token' => 'foo_token') }

    it { is_expected.to compile.and_raise_error(%r{ please specify either user/password or oauth_token not both. }) }
  end

  context 'without any credentials' do
    let(:params) do
      super()
        .tap { |hs| hs.delete('user') }
        .tap { |hs| hs.delete('password') }
    end

    it { is_expected.to compile.and_raise_error(%r{ please specify either user/password or oauth_token }) }
  end

  context 'with only a user' do
    let(:params) { super().tap { |hs| hs.delete('password') } }

    it { is_expected.to compile.and_raise_error(%r{ missing password }) }
  end

  context 'with only a password' do
    let(:params) { super().tap { |hs| hs.delete('user') } }

    it { is_expected.to compile.and_raise_error(%r{ missing user }) }
  end

  context 'checking the report processor for any changes' do
    before(:each) do
      # This handles cases when Puppet::FileSystem is called outside of our
      # module
      allow(Puppet::FileSystem).to receive(:read).and_call_original
    end

    context 'when the module fails to read the metadata.json file' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_raise('failed to access file')
      end

      it { is_expected.to compile.and_raise_error(%r{access.*file}) }
    end

    context 'when the module fails to access the settings file' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_return('{"version":"1"}')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_raise('failed to access file')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_version: 1}) }
      it { is_expected.to contain_file(settings_file_path).that_notifies('Service[pe-puppetserver]') }
    end

    context 'when the stored version does not match the current version' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_return('{"version":"1"}')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_return('report_processor_version' => '2')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_version: 1}) }
      it { is_expected.to contain_file(settings_file_path).that_notifies('Service[pe-puppetserver]') }
    end

    context 'when the stored version matches the current version' do
      before(:each) do
        allow(Puppet::FileSystem).to receive(:read).with(%r{metadata.json}).and_return('{"version":"1"}')
        allow(YAML).to receive(:load_file).with(settings_file_path).and_return('report_processor_version' => '1')
      end

      it { is_expected.to contain_file(settings_file_path).with_content(%r{report_processor_version: 1}) }
      it { is_expected.not_to contain_file(settings_file_path).that_notifies(['Service[pe-puppetserver]']) }
    end
  end

  context 'settings file' do
    it { is_expected.to contain_file(settings_file_path).with_content(%r{operation_mode: #{operation_mode}}) }

    context 'validation' do
      context 'default servicenow_credentials_validation_table' do
        it { is_expected.to contain_file(settings_file_path).with_validate_cmd(%r{#{default_validation_table}}) }
      end

      context 'user-specified servicenow_credentials_validation_table' do
        let(:params) do
          super().merge('servicenow_credentials_validation_table' => 'foo_validation_table')
        end

        it { is_expected.to contain_file(settings_file_path).with_validate_cmd(%r{foo_validation_table}) }
      end
    end
  end
end
