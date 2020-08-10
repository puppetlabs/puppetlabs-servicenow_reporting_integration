# The possible incident creation conditions. Here's what each condition means:
#   'always'
#       Always create an incident for _all_ reports
#   'never'
#       Never create an incident for _any_ report
#   'failures'
#       Create an incident if the report has failures
#   'corrective_changes'
#       Create an incident if the report contains at least one corrective change
#   'intentional_changes'
#       Create an incident if the report contains at least one intentional change
#   'pending_corrective_changes'
#       Create an incident if the report contains at least one corrective change
#       that wasn't applied because of noop
#   'pending_intentional_changes'
#       Create an incident if the report contains at least one intentional change
#       that wasn't applied because of noop
type Servicenow_reporting_integration::IncidentCreationConditions = Array[Enum[
  'always',
  'never',
  'failures',
  'corrective_changes',
  'intentional_changes',
  'pending_corrective_changes',
  'pending_intentional_changes',
]]
