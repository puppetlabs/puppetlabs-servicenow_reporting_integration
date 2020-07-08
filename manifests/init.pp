# @summary Configures the servicenow
#
# @example
#   include servicenow_reporting_integration
# @param [String] instance
#   The FQDN of the ServiceNow instance to query
# @param [String] user
#   The username of the account with permission to query data
# @param [String] password
#   The password of the account used to query data from Servicenow
class servicenow_reporting_integration (
  String $instance,
  String $user,
  String $password,
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
        instance => $instance,
        user     => $user,
        password => $password,
      }),
    }
  ])

  # Calculate $reports_setting. Idea here is that if the user already included
  # the 'servicenow' report processor, we return the setting as-is. Otherwise,
  # we return the setting _with_ the report processor included.
  #
  # Note: much of this code was inspired by https://github.com/puppetlabs/puppet/blob/6.16.0/lib/puppet/transaction/report.rb.
  # Also we use inline_template because $settings::reports != Puppet[:reports] and we want Puppet[:reports] since that's
  # what the report processor code (transaction/report.rb) uses.
  $raw_reports_setting = inline_template('<%= Puppet[:reports] %>')
  if $raw_reports_setting == 'none' {
    $reports_setting = 'servicenow'
  } else {
    $reports = split(regsubst($raw_reports_setting, /(^\s+)|(\s+$)/, '', 'G'), /\s*,\s*/)
    if 'servicenow' in $reports {
      # Use the raw setting so that Puppet won't mark it as changed
      $reports_setting = $raw_reports_setting
    } else {
      $reports_setting = join($reports + ['servicenow'], ', ')
    }
  }

  # Update the reports setting in puppet.conf
  ini_setting { 'puppetserver puppetconf add servicenow report processor':
    ensure  => present,
    path    => "${puppet_base}/puppet.conf",
    setting => 'reports',
    value   => $reports_setting,
    section => 'master',
    notify  => Service['pe-puppetserver'],
    require => $resource_dependencies,
  }
}
