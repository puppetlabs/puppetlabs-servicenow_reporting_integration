# This function gets the report processor version and stores it in the settings_file hash
Puppet::Functions.create_function(:'servicenow_reporting_integration::check_report_processor') do
  require 'json'
  require 'yaml'
  # @param settings_file_path
  #   The path to the settings file
  # @return [Array] Returns an array of a boolean value (if the stored ver is same as current ver)
  #   and  a string value (current version)
  dispatch :check_report_processor do
    param 'String', :settings_file_path
  end

  def check_report_processor(settings_file_path)
    module_dir = call_function('module_directory', 'servicenow_reporting_integration')
    metadata_json_path = "#{module_dir}/metadata.json"

    # Get the report processor's current version (should be the same as the version
    # in the metadata.json file)
    current_version = nil
    begin
      raw_metadata_json = Puppet::FileSystem.read(metadata_json_path)
      metadata_json = JSON.parse(raw_metadata_json)
      current_version = metadata_json['version']
    rescue StandardError => e
      raise Puppet::Error, "failed to calculate the 'servicenow' report processor's current version: #{e}"
    end

    # Get the stored version (if it exists)
    stored_version = nil
    begin
      settings_hash = YAML.load_file(settings_file_path)
      stored_version = settings_hash['report_processor_version'].to_s
    rescue StandardError
      # Assume that an error means that the stored version doesn't exist (possible if e.g. the settings
      # file hasn't been created yet). We leave the handling of more serious errors (like 'invalid permissions')
      # to the File[<settings_file_path>] resource.
      stored_version = ''
    end
    report_processor_changed = (stored_version != current_version) ? true : false

    [report_processor_changed, current_version]
  end
end
