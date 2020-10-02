# The valid Servicenow event severity levels. Here's what each level means:
#   'Clear'
#       The alert no longer needs action.
#   'Critical'
#       The resource is either not functional or critical problems are imminent.
#   'Major'
#       Major functionality is severely impaired or performance has degraded.
#   'Minor'
#       Partial, non-critical loss of functionality or performance degradation occurred.
#   'Warning'
#       Attention is required, even though the resource is still functional.
#   'OK'
#       No severity. An alert is created. The resource is still functional.
# https://docs.servicenow.com/bundle/paris-it-operations-management/page/product/event-management-operator/concept/operator-events-alerts.html
type Servicenow_reporting_integration::Severity_levels = Enum[
  'Clear',
  'Critical',
  'Major',
  'Minor',
  'Warning',
  'OK',
]
