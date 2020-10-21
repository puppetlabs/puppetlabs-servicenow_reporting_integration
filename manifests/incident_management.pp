# TODO: Properly document this class
#
# @summary Configures the servicenow
#
# @example
#  include servicenow_reporting_integration::incident_management
# @param [String[1]] instance
#   The FQDN of the ServiceNow instance
# @param [String[1]] caller_id
#   The sys_id of the incident's caller as specified in the sys_user table
#  parameter to the empty string ''.
# @param [String] user
#   The username of the account with permission to query data
# @param [String] password
#   The password of the account used to query data from Servicenow
# @param [String] oauth_token
#   An OAuth access token created in Servicenow that can be used in place of a
# @param [String[1]] pe_console_url
#   The PE console url
#   username and password.
# @param [Optional[String[1]]] category
#   The incident's category
# @param [Optional[String[1]]] subcategory
#   The incident's subcategory
# @param [Optional[String[1]]] contact_type
#   The incident's contact type
# @param[Optional[Integer]] state
#   The incident's state
# @param[Optional[Integer]] impact
#   The incident's impact
# @param[Optional[Integer]] urgency
#   The incident's urgency
# @param [Optional[String[1]]] assignment_group
#   The sys_id of the incident's assignment group as specified in the
#   sys_user_group table
# @param [Optional[String[1]]] assigned_to
#   The sys_id of the user assigned to the incident as specified in the
#   sys_user table. Note that if assignment_group is also specified, then
#   this must correspond to a user who is a member of the assignment_group.
# @param [Servicenow_reporting_integration::IncidentCreationConditions] incident_creation_conditions
#   The incident creation conditions. The report processor will create incidents for reports
#   that satisfy at least one of the specified conditions. For example, if you use the default
#   value (`['failures', 'corrective_changes']`), then the report processor will create an
#   incident if the report had any failures _or_ corrective changes.
#   Note: Set this parameter to `['never']` if you want to completely turn off incident creation.
#   If set to `['never']`, then this module will not create any incidents at all.
# @param [String] servicenow_credentials_validation_table
#   The table to read for validating the provided ServiceNow credentials.
#   You should set this to another table if the current set of credentials
#   don't have READ access to the default 'incident' table. Note that you
#   can turn the ServiceNow credentials validation off by setting this
# @param [Optional[Array[String[1]]]] include_facts
#   An array of fact queries to send with each event. The query can be the simple
#   name of a top level fact like 'id', or it can be a dot notation query for
#   nested facts like 'os.distro'
# @param [Enum['yaml', 'pretty_jason', 'json']] facts_format
#   The format of the facts that are included in the event description
# @param [Optional[Boolean]] skip_certificate_validation
#   If your Servicenow instance uses a certificate that is not trusted by the
#   Puppet server, you can set this parameter to 'true'. The connection will
#   still use SSL, but the module will not perform certificate validation, which
#   is a risk for man in the middle attacks.
class servicenow_reporting_integration::incident_management (
  String[1] $instance,
  String[1] $caller_id,
  Optional[String[1]] $user                                                                  = undef,
  Optional[String[1]] $password                                                              = undef,
  Optional[String[1]] $oauth_token                                                           = undef,
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
  String $servicenow_credentials_validation_table                                            = 'incident',
  Optional[Array[String[1]]] $include_facts                                                  = ['aio_agent_version', 'id', 'memorysize', 'memoryfree', 'ipaddress', 'ipaddress6', 'os.distro', 'os.windows', 'path', 'uptime', 'rubyversion'],
  Enum['yaml', 'pretty_json', 'json'] $facts_format                                          = 'yaml',
  Optional[Boolean] $skip_certificate_validation                                             = false,
) {
  class { 'servicenow_reporting_integration':
    operation_mode                          => 'incident_management',
    instance                                => $instance,
    caller_id                               => $caller_id,
    user                                    => $user,
    password                                => $password,
    oauth_token                             => $oauth_token,
    pe_console_url                          => $pe_console_url,
    category                                => $category,
    subcategory                             => $subcategory,
    contact_type                            => $contact_type,
    state                                   => $state,
    impact                                  => $impact,
    urgency                                 => $urgency,
    assignment_group                        => $assignment_group,
    assigned_to                             => $assigned_to,
    incident_creation_conditions            => $incident_creation_conditions,
    servicenow_credentials_validation_table => $servicenow_credentials_validation_table,
    include_facts                           => $include_facts,
    facts_format                            => $facts_format,
    skip_certificate_validation             => $skip_certificate_validation,
  }
}
