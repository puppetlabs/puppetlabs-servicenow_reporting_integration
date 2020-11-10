# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog] and this project adheres to [Semantic Versioning].


## [Unreleased]

### Added

### Changed

### Fixed

- Settings validation script failed with non-PE issued Console Certificate ([PIE-415]) [#71]

### Removed

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

<!-- Pull Request Links -->

[#68]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/68
[#69]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/69
[#71]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/71

<!-- Version Comparison Links -->

[Unreleased]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/compare/v0.1.1...HEAD
[Release 0.1.1]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/compare/v0.1.0...v0.1.1
[Release 0.1.0]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/tree/v0.1.0

[Keep a Changelog]: http://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: http://semver.org