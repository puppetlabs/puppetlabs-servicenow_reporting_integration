# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog] and this project adheres to [Semantic Versioning].


## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [Release 0.2.2] - (2022-2-1)

### Added

- Add Environment filter ([PIE-523]) [#81]
- Add Report Filter for Events ([PIE-522]) [#78]

### Fixed

- Settings validation script failed with non-PE issued Console Certificate ([PIE-415]) [#71]
- Allow for the timeout parameters to accept either integer or float values ([PIE-998]) [#100]
- Prevent Trailing Slash in PE Console URL ([PIE-448]) [#72]

## [Release 0.1.1] - (2020-11-09)

### Fixed

- Fixed issue with event grouping on resource change events. ([PIE-409]) [#68]
- Added a check to `add_ignore_ok_events_rule` task to ensure variable is assigned before use. [#69]

## [Release 0.1.0] - (2020-10-27)

Initial Release

<!-- Reference links section -->

<!-- Ticket Links -->

[PIE-415]: https://tickets.puppetlabs.com/browse/PIE-415
[PIE-409]: https://tickets.puppetlabs.com/browse/PIE-409
[PIE-523]: https://tickets.puppetlabs.com/browse/PIE-523
[PIE-522]: https://tickets.puppetlabs.com/browse/PIE-522
[PIE-415]: https://tickets.puppetlabs.com/browse/PIE-415
[PIE-998]: https://tickets.puppetlabs.com/browse/PIE-998
[PIE-448]: https://tickets.puppetlabs.com/browse/PIE-448
[PIE-415]: https://tickets.puppetlabs.com/browse/PIE-415

<!-- Pull Request Links -->

[#68]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/68
[#69]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/69
[#71]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/71
[#81]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/81
[#78]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/78
[#100]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/100
[#72]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/72

<!-- Version Comparison Links -->

[Unreleased]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/compare/v0.2.2...HEAD
[Release 0.2.2]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/compare/v0.1.1...v0.2.2
[Release 0.1.1]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/compare/v0.1.0...v0.1.1
[Release 0.1.0]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/tree/v0.1.0

[Keep a Changelog]: http://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: http://semver.org