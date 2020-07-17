# @summary Configures the servicenow
#
# @example
#   include servicenow_reporting_integration
# @param [String] instance
#   The FQDN of the ServiceNow instance
# @param [String] user
#   The username of the account
# @param [String] password
#   The password of the account
# @param [String] pe_console_url
#   The PE console url
class servicenow_reporting_integration (
  String $instance,
  String $user,
  String $password,
  String $pe_console_url,
) {
  # Warning: These values are parameterized here at the top of this file, but the
  # path to the yaml file is hard coded in the report processor
  $puppet_base = '/etc/puppetlabs/puppet'

  $resource_dependencies = flatten([
    file { "${puppet_base}/servicenow_reporting.yaml":
      ensure  => file,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      mode    => '0640',
      content => epp('servicenow_reporting_integration/servicenow_reporting.yaml.epp', {
        instance       => $instance,
        user           => $user,
        password       => $password,
        pe_console_url => $pe_console_url,
      }),
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
    notify               => Service['pe-puppetserver'],
    require              => $resource_dependencies,
  }
}
