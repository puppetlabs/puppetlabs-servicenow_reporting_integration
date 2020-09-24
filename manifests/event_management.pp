# @summary Configures the report processor to send events to servicenow
#
# @example
#   include servicenow_reporting_integration::event_management
# @param [String[1]] instance
#   The FQDN of the ServiceNow instance. Only the FQDN. Do not include the protocol
# @param [Optional[String[1]]] user
#   A user that has permission to send events
# @param [Optional[String[1]]] password
#   The password for the user
# @param [Optional[String[1]]] oauth_token
#   You can use an oauth token instead of username and password if you choose
# @param [Optional[String[1]]] pe_console_url
#   The url to access the PE console. Used to link users back to the console
# @param [String] servicenow_credentials_validation_table
#   The name of a table to query that can be used to validate that the credentials
#   provided will work to send events.
# @param [Optional[Integer[0, 5]]] failures_event_severity
#   The severity to assign to events when the report contains errors
# @param [Optional[Integer[0, 5]]] corrective_changes_event_severity
#   The severity to assign to events when the report contains corrective changes
# @param [Optional[Integer[0, 5]]] intentional_changes_event_severity
#   The severity to assign to events when the report contains intentional changes
# @param [Optional[Integer[0, 5]]] pending_corrective_changes_event_severity
#   The severity to assign to events when the report contains pending corrective changes
# @param [Optional[Integer[0, 5]]] pending_intential_changes_event_severity
#   The severity to assign to events when the report contains pending intentional changes
# @param [Optional[Integer[0, 5]]] no_changes_event_severity
#   The severity to assign to events when the report contains no events
# @param [Optional[Array[String[1]]]] include_facts
#   An array of fact queries to send with each event. The query can be the simple
#   name of a top level fact like 'id', or it can be a dot notation query for
#   nested facts like 'os.distro'
# @param [Enum['yaml', 'pretty_jason', 'json']] facts_format
#   The format of the facts that are included in the event description

class servicenow_reporting_integration::event_management (
  String[1] $instance,
  Optional[String[1]] $user                                           = undef,
  Optional[String[1]] $password                                       = undef,
  Optional[String[1]] $oauth_token                                    = undef,
  Optional[String[1]] $pe_console_url                                 = undef,
  String $servicenow_credentials_validation_table                     = 'em_event',
  Optional[Integer[0, 5]] $failures_event_severity                    = 3,
  Optional[Integer[0, 5]] $corrective_changes_event_severity          = 2,
  Optional[Integer[0, 5]] $intentional_changes_event_severity         = 1,
  Optional[Integer[0, 5]] $pending_corrective_changes_event_severity  = 2,
  Optional[Integer[0, 5]] $pending_intentional_changes_event_severity = 1,
  Optional[Integer[0, 5]] $no_changes_event_severity                  = 1,
  Optional[Array[String[1]]] $include_facts                           = ['aio_agent_version', 'id', 'memorysize', 'memoryfree', 'ipaddress', 'ipaddress6', 'os.distro', 'os.windows', 'path', 'uptime', 'rubyversion'],
  Enum['yaml', 'pretty_json', 'json'] $facts_format                   = 'yaml',
) {
  class { 'servicenow_reporting_integration':
    operation_mode                             => 'event_management',
    instance                                   => $instance,
    user                                       => $user,
    password                                   => $password,
    oauth_token                                => $oauth_token,
    pe_console_url                             => $pe_console_url,
    servicenow_credentials_validation_table    => $servicenow_credentials_validation_table,
    failures_event_severity                    => $failures_event_severity,
    corrective_changes_event_severity          => $corrective_changes_event_severity,
    intentional_changes_event_severity         => $intentional_changes_event_severity,
    pending_corrective_changes_event_severity  => $pending_corrective_changes_event_severity,
    pending_intentional_changes_event_severity => $pending_intentional_changes_event_severity,
    no_changes_event_severity                  => $no_changes_event_severity,
    include_facts                              => $include_facts,
    facts_format                               => $facts_format,
  }
}
