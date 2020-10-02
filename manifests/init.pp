# @summary
#   This class contains the common setup code for servicenow_reporting_integration::incident_management
#   and servicenow_reporting_integration::event_management.
# 
# @api private
class servicenow_reporting_integration (
  # OPERATION MODE
  Enum['event_management', 'incident_management'] $operation_mode,
  # COMMON PARAMETERS
  String[1] $instance,
  Optional[String[1]] $user                                                                            = undef,
  Optional[String[1]] $password                                                                        = undef,
  Optional[String[1]] $oauth_token                                                                     = undef,
  Optional[String] $servicenow_credentials_validation_table                                            = undef,
  Optional[String[1]] $pe_console_url                                                                  = undef,
  Optional[Array[String[1]]] $include_facts                                                            = ['identity.user', 'ipaddress','memorysize', 'memoryfree', 'os'],
  Enum['yaml', 'pretty_json', 'json'] $facts_format                                                    = 'pretty_json',
  # PARAMETERS SPECIFIC TO INCIDENT_MANAGEMENT
  Optional[String[1]] $caller_id                                                                       = undef,
  Optional[String[1]] $category                                                                        = undef,
  Optional[String[1]] $subcategory                                                                     = undef,
  Optional[String[1]] $contact_type                                                                    = undef,
  Optional[Integer] $state                                                                             = undef,
  Optional[Integer] $impact                                                                            = undef,
  Optional[Integer] $urgency                                                                           = undef,
  Optional[String[1]] $assignment_group                                                                = undef,
  Optional[String[1]] $assigned_to                                                                     = undef,
  Optional[Servicenow_reporting_integration::IncidentCreationConditions] $incident_creation_conditions = undef,
  # PARAMETERS SPECIFIC TO EVENT_MANAGEMENT
  Optional[Servicenow_reporting_integration::Severity_levels] $failures_event_severity                                                           = undef,
  Optional[Servicenow_reporting_integration::Severity_levels] $corrective_changes_event_severity                                                 = undef,
  Optional[Servicenow_reporting_integration::Severity_levels] $intentional_changes_event_severity                                                = undef,
  Optional[Servicenow_reporting_integration::Severity_levels] $pending_corrective_changes_event_severity                                         = undef,
  Optional[Servicenow_reporting_integration::Severity_levels] $pending_intentional_changes_event_severity                                        = undef,
  Optional[Servicenow_reporting_integration::Severity_levels] $no_changes_event_severity                                                         = undef,
) {
  if (($user or $password) and $oauth_token) {
    fail('please specify either user/password or oauth_token not both.')
  }

  unless ($user or $password or $oauth_token) {
    fail('please specify either user/password or oauth_token')
  }

  if ($user or $password) {
    if $user == undef {
      fail('missing user')
    } elsif $password == undef {
      fail('missing password')
    }
  }

  if ($pe_console_url == undef) {
    # In a monolithic install this value will always be correct. For a multi master
    # or a multiple compile masters scenario, this will most likely point at the
    # Master of Masters and still be correct. If for some reason it's wrong, the
    # user can still provide their own value for $pe_console_url.
    $final_console_url = "https://${settings::report_server}"
  }
  else {
    $final_console_url = $pe_console_url
  }

  # If the report processor changed between module versions then we need to restart puppetserver.
  # To detect when the report processor changed, we compare its current version with the version
  # stored in the settings file. This is handled by the 'check_report_processor' custom function.
  #
  # Note that the $report_processor_changed variable is necessary to avoid restarting pe-puppetserver
  # everytime the settings file changes due to non-report processor reasons (like e.g. if the ServiceNow
  # credentials change). We also return the current report processor version so that we can persist it
  # in the settings file.
  #
  # The confdir defaults to /etc/puppetlabs/puppet on *nix systems
  # https://puppet.com/docs/puppet/5.5/configuration.html#confdir
  $settings_file_path = "${settings::confdir}/servicenow_reporting.yaml"
  [$report_processor_changed, $report_processor_version] = servicenow_reporting_integration::check_report_processor($settings_file_path)  if $report_processor_changed {
    # Restart puppetserver to pick-up the changes
    $settings_file_notify = [Service['pe-puppetserver']]
  } else {
    $settings_file_notify = []
  }
  file { $settings_file_path:
    ensure       => file,
    owner        => 'pe-puppet',
    group        => 'pe-puppet',
    mode         => '0640',
    # The '%' is a validate_cmd convention; it corresponds to the settings file's
    # (temporary) path containing the new content. We also quote the validation_table
    # argument since that can be an empty string. Finally, this manifest's invoked on
    # a puppetserver node so the module_directory and the validate_settings.rb script
    # should always exist.
    validate_cmd => "/opt/puppetlabs/puppet/bin/ruby ${module_directory('servicenow_reporting_integration')}/files/validate_settings.rb % '${servicenow_credentials_validation_table}'",
    content      => epp('servicenow_reporting_integration/servicenow_reporting.yaml.epp', {
      instance                                   => $instance,
      operation_mode                             => $operation_mode,
      pe_console_url                             => $final_console_url,
      caller_id                                  => $caller_id,
      user                                       => $user,
      password                                   => $password,
      oauth_token                                => $oauth_token,
      category                                   => $category,
      subcategory                                => $subcategory,
      contact_type                               => $contact_type,
      state                                      => $state,
      impact                                     => $impact,
      urgency                                    => $urgency,
      assignment_group                           => $assignment_group,
      assigned_to                                => $assigned_to,
      incident_creation_conditions               => $incident_creation_conditions ,
      report_processor_version                   => $report_processor_version,
      failures_event_severity                    => $failures_event_severity,
      corrective_changes_event_severity          => $corrective_changes_event_severity,
      intentional_changes_event_severity         => $intentional_changes_event_severity,
      pending_corrective_changes_event_severity  => $pending_corrective_changes_event_severity,
      pending_intentional_changes_event_severity => $pending_intentional_changes_event_severity,
      no_changes_event_severity                  => $no_changes_event_severity,
      include_facts                              => $include_facts,
      facts_format                               => $facts_format,
      }),
    notify       => $settings_file_notify,
  }

  # Update the reports setting in puppet.conf
  ini_subsetting { 'puppetserver puppetconf add servicenow report processor':
    ensure               => present,
    path                 => $settings::config,
    section              => 'master',
    setting              => 'reports',
    subsetting           => 'servicenow',
    subsetting_separator => ',',
    # Note that Puppet refreshes resources only once so multiple notifies
    # in a single run are safe. In our case, this means that if the settings
    # file resource and the ini_subsetting resource both notify pe-puppetserver,
    # then pe-puppetserver will be refreshed (restarted) only once.
    notify               => Service['pe-puppetserver'],
    require              => File[$settings_file_path],
  }
}
