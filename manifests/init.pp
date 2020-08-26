# @summary Configures the servicenow
#
# @example
#   include servicenow_reporting_integration
# @param [String[1]] instance
#   The FQDN of the ServiceNow instance
# @param [String[1]] pe_console_url
#   The PE console url
# @param [String[1]] caller_id
#  The sys_id of the incident's caller as specified in the sys_user table
# @param [String] servicenow_credentials_validation_table
#  The table to read for validating the provided ServiceNow credentials.
#  You should set this to another table if the current set of credentials
#  don't have READ access to the default 'incident' table. Note that you
#  can turn the ServiceNow credentials validation off by setting this
#  parameter to the empty string ''.
# @param [String] user
#  The username of the account with permission to query data
# @param [String] password
#  The password of the account used to query data from Servicenow
# @param [String] oauth_token
#  An OAuth access token created in Servicenow that can be used in place of a
#  username and password.
# @param [Optional[String[1]]] category
#  The incident's category
# @param [Optional[String[1]]] subcategory
#  The incident's subcategory
# @param [Optional[String[1]]] contact_type
#  The incident's contact type
# @param[Optional[Integer]] state
#  The incident's state
# @param[Optional[Integer]] impact
#  The incident's impact
# @param[Optional[Integer]] urgency
#  The incident's urgency
# @param [Optional[String[1]]] assignment_group
#  The sys_id of the incident's assignment group as specified in the
#  sys_user_group table
# @param [Optional[String[1]]] assigned_to
#  The sys_id of the user assigned to the incident as specified in the
#  sys_user table. Note that if assignment_group is also specified, then
#  this must correspond to a user who is a member of the assignment_group.
# @param [Servicenow_reporting_integration::IncidentCreationConditions] incident_creation_conditions
#  The incident creation conditions. The report processor will create incidents for reports
#  that satisfy at least one of the specified conditions. For example, if you use the default
#  value (`['failures', 'corrective_changes']`), then the report processor will create an
#  incident if the report had any failures _or_ corrective changes.
#
#  Note: Set this parameter to `['never']` if you want to completely turn off incident creation.
#  If set to `['never']`, then this module will not create any incidents at all.
class servicenow_reporting_integration (
  String[1] $instance,
  Optional[String[1]] $user                                                                  = undef,
  Optional[String[1]] $password                                                              = undef,
  Optional[String[1]] $oauth_token                                                           = undef,
  Enum['event_management', 'incident_management'] $operation_mode                            = 'event_management',
  Optional[String[1]] $caller_id                                                             = undef,
  Optional[String[1]] $pe_console_url                                                        = undef,
  Optional[String[1]] $category                                                              = undef,
  Optional[String[1]] $subcategory                                                           = undef,
  Optional[String[1]] $contact_type                                                          = undef,
  Optional[Integer] $state                                                                   = undef,
  Optional[Integer] $impact                                                                  = undef,
  Optional[Integer] $urgency                                                                 = undef,
  Optional[String[1]] $assignment_group                                                      = undef,
  Optional[String[1]] $assigned_to                                                           = undef,
  Servicenow_reporting_integration::IncidentCreationConditions $incident_creation_conditions = ['failures', 'corrective_changes'],
  Optional[String] $servicenow_credentials_validation_table                                  = undef,
) {
  if $operation_mode == 'incident_management' {
    unless $caller_id {
      # caller_id's a required incident field so make sure its set if we're operating
      # under 'incident_management' mode
      fail('please specify the caller_id')
    }
  }

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

  if $servicenow_credentials_validation_table {
    $credentials_validation_table = $servicenow_credentials_validation_table
  } elsif $operation_mode == 'event_management' {
    $credentials_validation_table = 'em_event'
  } else {
    $credentials_validation_table = 'incident'
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
    validate_cmd => "/opt/puppetlabs/puppet/bin/ruby ${module_directory('servicenow_reporting_integration')}/files/validate_settings.rb % '${credentials_validation_table}'",
    content      => epp('servicenow_reporting_integration/servicenow_reporting.yaml.epp', {
      instance                     => $instance,
      operation_mode               => $operation_mode,
      pe_console_url               => $final_console_url,
      caller_id                    => $caller_id,
      user                         => $user,
      password                     => $password,
      oauth_token                  => $oauth_token,
      category                     => $category,
      subcategory                  => $subcategory,
      contact_type                 => $contact_type,
      state                        => $state,
      impact                       => $impact,
      urgency                      => $urgency,
      assignment_group             => $assignment_group,
      assigned_to                  => $assigned_to,
      incident_creation_conditions => $incident_creation_conditions ,
      report_processor_version     => $report_processor_version,
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
