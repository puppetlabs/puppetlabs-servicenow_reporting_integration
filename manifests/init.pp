# @summary Configures the servicenow
#
# @example
#   include servicenow_reporting_integration
# @param [String[1]] instance
#   The FQDN of the ServiceNow instance
# @param [String[1]] user
#   The username of the account
# @param [String[1]] password
#   The password of the account
# @param [String[1]] pe_console_url
#   The PE console url
# @param [String[1]] caller_id
#  The sys_id of the incident's caller as specified in the sys_user table
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
# @params [Array[Enum['failed_changes', 'corrective_changes', 'intentional_changes', 'all', 'none'], 1, 3]] incident_creation_report_statuses
#   The kinds of report status attributes that can trigger an incident to be sent to Servicenow.
#   Choose any of ['failed_changes', 'corrective_changes', 'intentional_changes', 'pending_changes', 'all', 'none', 'unchanged']
#   You can also specify 'all' to create incidents for all report statuses or 'none' to completely turn off incident creation
class servicenow_reporting_integration (
  String[1] $instance,
  String[1] $user,
  String[1] $password,
  String[1] $pe_console_url,
  String[1] $caller_id,
  Optional[String[1]] $category         = undef,
  Optional[String[1]] $subcategory      = undef,
  Optional[String[1]] $contact_type     = undef,
  Optional[Integer] $state              = undef,
  Optional[Integer] $impact             = undef,
  Optional[Integer] $urgency            = undef,
  Optional[String[1]] $assignment_group = undef,
  Optional[String[1]] $assigned_to      = undef,
  Servicenow_reporting_integration::Statuses $incident_creation_report_attributes = ['failed_changes','corrective_changes'],
) {
  # Warning: These values are parameterized here at the top of this file, but the
  # path to the yaml file is hard coded in the report processor
  $puppet_base = '/etc/puppetlabs/puppet'

  # If the report processor changed between module versions then we need to restart puppetserver.
  # To detect when the report processor changed, we compare its current checksum with the checksum
  # stored in the settings file. This is handled by the 'check_report_processor' custom function.
  #
  # Note that the $report_processor_changed variable is necessary to avoid restarting pe-puppetserver
  # everytime the settings file changes due to non-report processor reasons (like e.g. if the ServiceNow
  # credentials change). We also return the current report processor checksum so that we can persist it
  # in the settings file.
  $settings_file_path = "${puppet_base}/servicenow_reporting.yaml"
  [$report_processor_changed, $report_processor_checksum] = servicenow_reporting_integration::check_report_processor($settings_file_path)
  if $report_processor_changed {
    # Restart puppetserver to pick-up the changes
    $settings_file_notify = [Service['pe-puppetserver']]
  } else {
    $settings_file_notify = []
  }
  $resource_dependencies = flatten([
    file { $settings_file_path:
      ensure  => file,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      mode    => '0640',
      content => epp('servicenow_reporting_integration/servicenow_reporting.yaml.epp', {
        instance                            => $instance,
        user                                => $user,
        password                            => $password,
        pe_console_url                      => $pe_console_url,
        caller_id                           => $caller_id,
        category                            => $category,
        subcategory                         => $subcategory,
        contact_type                        => $contact_type,
        state                               => $state,
        impact                              => $impact,
        urgency                             => $urgency,
        assignment_group                    => $assignment_group,
        assigned_to                         => $assigned_to,
        incident_creation_report_attributes => $incident_creation_report_attributes,
        report_processor_checksum           => $report_processor_checksum,
      }),
      notify  => $settings_file_notify,
    }
  ])

  # Update the reports setting in puppet.conf
  ini_subsetting { 'puppetserver puppetconf add servicenow report processor':
    ensure               => present,
    path                 => "${puppet_base}/puppet.conf",
    section              => 'master',
    setting              => 'reports',
    subsetting           => 'servicenow',
    subsetting_separator => ',',
    # Note that Puppet refreshes resources only once so multiple notifies
    # in a single run are safe. In our case, this means that if the settings
    # file resource and the ini_subsetting resource both notify pe-puppetserver,
    # then pe-puppetserver will be refreshed (restarted) only once.
    notify               => Service['pe-puppetserver'],
    require              => $resource_dependencies,
  }
}
