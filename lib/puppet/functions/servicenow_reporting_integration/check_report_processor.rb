Puppet::Functions.create_function(:'servicenow_reporting_integration::check_report_processor') do
  require 'yaml'

  dispatch :check_report_processor do
    param 'String', :settings_file_path
  end

  def check_report_processor(settings_file_path)
    module_dir = call_function('module_directory', 'servicenow_reporting_integration')
    report_processor_path = "#{module_dir}/lib/puppet/reports/servicenow.rb"

    # Get the report processor's current checksum
    current_checksum = nil
    begin
      current_checksum = Puppet::Util::Checksums.sha256_file(report_processor_path)
    rescue StandardError => e
      raise Puppet::Error, "failed to calculate the 'servicenow' report processor's current sha256 checksum: #{e}"
    end

    # Get the stored checksum (if it exists)
    stored_checksum = nil
    begin
      settings_hash = YAML.load_file(settings_file_path)
      stored_checksum = settings_hash['report_processor_checksum'].to_s
    rescue StandardError
      # Assume that an error means that the stored checksum doesn't exist (possible if e.g. the settings
      # file hasn't been created yet). We leave the handling of more serious errors (like 'invalid permissions')
      # to the File[<settings_file_path>] resource.
      stored_checksum = ''
    end
    report_processor_changed = (stored_checksum != current_checksum) ? true : false

    [report_processor_changed, current_checksum]
  end
end
