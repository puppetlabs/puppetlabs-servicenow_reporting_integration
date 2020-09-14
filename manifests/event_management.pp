# TODO: Properly document this class
class servicenow_reporting_integration::event_management (
  String[1] $instance,
  Optional[String[1]] $user                                                                  = undef,
  Optional[String[1]] $password                                                              = undef,
  Optional[String[1]] $oauth_token                                                           = undef,
  Optional[String[1]] $pe_console_url                                                        = undef,
  String $servicenow_credentials_validation_table                                            = 'em_event',
) {
  class { 'servicenow_reporting_integration':
    operation_mode                          => 'event_management',
    instance                                => $instance,
    user                                    => $user,
    password                                => $password,
    oauth_token                             => $oauth_token,
    pe_console_url                          => $pe_console_url,
    servicenow_credentials_validation_table => $servicenow_credentials_validation_table,
  }
}
