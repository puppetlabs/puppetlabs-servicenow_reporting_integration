# puppetlabs-servicenow_reporting_integration

The ServiceNow reporting integration module ships with a `servicenow` report processor that can send one of two kinds of information back to Servicenow. It can send events that are handled by servicenow to create Alerts and Incidents, or you can create Incidents directly.

#### Table of Contents

1. [Pre-reqs](#pre-reqs)
2. [Setup](#setup)
    * [Events](#events)
    * [Incidents](#incidents)
3. [Troubleshooting](#troubleshooting)
4. [Development](#development)

## Pre-reqs

* Puppet Enterprise version 2019.8.1 (LTS) or newer
* A ServiceNow instance (dev or enterprise)

## Setup

1. Install the `puppetlabs-servicenow_reporting_integration` module on your Puppet server.

The module can send events or it can create incidents, but attempting to do both will cause a catalog compilation failure. Please choose which one of the two you would like to do and only classify your Puppet server nodes with one of those classes, either event management, or incident management.

### Events

To send events, classify your Puppet servers with the `servicenow_reporting_integration::event_management` class. The minimum parameters you need to configure for the class to work are instance (the fqdn of the servicenow instance), and then user and password, or you can bypass username/password authentication and use an oauth token using the oauth_token parameter.

By default each event will include the following information:
* __Source__: Puppet
* __Node__: The node the agent ran on
* __Type__: The type of event. Can be one of node_report_changed, node_report_unchanged, node_report_failed
* __Source instance__: The name of the Puppet server that generated the report
* __Message Key__: A hash of all of the relevant report properties to ensure that future events are grouped together properly
* __Severity__: The highest severity rating of all of the events that occurred in a given run. These severity levels can be configured via the <change_type>_event_severity class parameters, including the severity of no_changes reports via no_changes_events_severity.
* __Description__: Contains the following:
  * __Report Labels__ - All of the different kinds of events that were in the Puppet run that generated this event. While severity is only the single highest severity, these labels tell you all of the kinds of events that occurred.
  * __Environment__ - The Puppet environment the node is assigned to.
  * __Resource Statuses__ - The full name of the resource, the name of the property and the event message, and the file and line where the resource was defined, for each resource event that was in the report. All resource events are included except for ‘audit’ events, which are resources for which nothing interesting happened; Puppet simply verified that they are currently still in the correct state.
  * __Facts__ - All of the facts that were requested via the `include_facts` parameter. The default format is yaml, but can be changed via the `facts_format` parameter.
* __Additional Information__: The additional information field contains data about the event in JSON format to make it easy to target that information for rules and workflows. It contains the following keys
  * __Facts__: A json format representation of all of the facts from the node where Puppet ran.
  * __Node Environment__: The environment the node is assigned to

The module will send a single event for every Puppet run on every node. If nothing interesting such as changes or a failure happened in a given Puppet run then the event type will be node_report_unchanged, there will be no resources listed in the description, and the report severity default value will be ‘ok’.

If a change happens then the event type and severity will be updated, and any resources that changed will be listed in the description.

If multiple events happen e.g. two resources make corrective changes, but a third resource fails, then the report type will be node_report_failure, the severity by default will be ‘Minor’. But all three resources, the resource message that describes what happened, and the file and line where the resource can be found, will be included in the event description.

Event severities can be configured via the <change_type>_event_severity class parameters.

You can specify the set of facts included in the event description via the `include_facts` parameter. It takes an array of strings that each represent a fact to retrieve from the available node facts set. Nested facts can be queried by dot notation such as `os.distro`, or `os.windows` to get the Windows version. Queries for nested facts must start at the top level fact name and any fact that is not present on a node, such as `os.windows` on a Linux box, is simply ignored without error.

Facts in the description by default are in Yaml format for readability, but this can be changed via the `facts_format` parameter to one of yaml, pretty_json (json with readability line breaks and indentation), or json.

### Incidents

To send incidents, classify your Puppet server nodes with the `servicenow_reporting_integration::incident_mangement` class. The minimum parameters you need to configure for the class to work are instance (the fqdn of the servicenow instance, not including the protocol e.g. https://), and then user and password, or you can bypass username/password authentication and use an oauth token using the oauth_token parameter. Lastly you will need to get the sys_id of the user you would like to use as the ‘Caller’ for each ticket. Look below in the ‘How To’ section if you don’t already know how to get a user sys_id. The `servicenow_reporting_integration::incident_management` class requires the `caller_id` because that is a required incident field on ServiceNow’s end. 

To get the desired `sys_id` from Servicenow:
1. In the Application Navigator (left sidebar navigation menu) navigate to System Security > Users and Groups > Users
2. Use the search box to search for the user you want.
3. In the user listing click on a user.
4. In the user properties screen, click on the hamburger menu (three vertical bars) to the right of the left arrow in the upper left corner of the screen.
5. Click on ‘Copy sys_id’ to copy the sys_id directly to the clipboard, or click on Show XML to see the sys_id in a new window along with the rest of the user’s properties.

The `servicenow` report processor creates a ServiceNow incident based on that report if at least one of the incident creation conditions are met. 

By default the incident_creation_conditions are `['failures', 'corrective_changes']`. This means an incident will be created if there was a resource failure, a catalog compilation failure, or if a corrective change was made to a managed resource during a Puppet run. With these default parameters intentional changes such as adding a new resource to the catalog and Puppet bringing it into compliance for the first time, and pending changes, like running an agent in noop mode and the agent reporting changes would have occurred, will not result in an incident in servicenow. If you would like to report on those types of changes please note that `intentional_changes`, `pending_corrective_changes`, and `pending_intentional_changes` are also available as values for this parameter. As a shortcut you can also specify `always`, or to temporarily stop the module from creating any incidents at all you can set the incident_creation_conditions parameter to `never`.

The incident_mangement class also lets you specify additional (but optional) incident fields like the `category`, `subcategory` and `assigned_to` fields via the corresponding `category`, `subcategory`, and `assigned_to` parameters, respectively. See the `REFERENCE.md` for the full details.

Each incident will include the following information provided by Puppet:
* __Caller__: The user specified by the `sys_id` given to the `caller_id` parameter of the incident_management class. This can be any user in Servicenow and doesn’t need to be the same as the user that creates the incident via the username/password or oauth_token parameters.
* __Urgency__: Defaults to 3 - Low. Configurable
* __Impact__: Defaults to 3 - Low. Configurable
* __State__: Defaults to New. Configurable
* __Short Description__: Contains the following information
  * __Status__: changed, unchanged, failed, pending changes
  * __Node__: the fqdn of the node the agent ran on
  * __Report Time__: The timestamp of the report to help find the report in the console
* __Description__: See the description section from event management above. Incidents will get the same description

## Troubleshooting

To verify that everything worked, trigger a Puppet run on one of the nodes in the `PE Master` node group then log into the node. Once logged in, run `sudo tail -n 60 /var/log/puppetlabs/puppetserver/puppetserver.log | grep servicenow`. You should see some output. If not, then the class is probably not being classified properly. Either the class is not being assigned to the Puppet server nodes at all, or there may be catalog compilation errors on those nodes with the provided parameter values. Please use GitHub issues to file any bugs you find during your troubleshooting.

## Development

### Unit tests
To run the unit tests:

```
bundle install
bundle exec rake spec_prep spec
```

### Acceptance tests
The acceptance tests use puppet-litmus in a multi-node fashion. The nodes consist of a 'master' node representing the PE master (and agent), and a 'ServiceNow' node representing the ServiceNow instance. All nodes are stored in a generated `inventory.yaml` file (relative to the project root) so that they can be used with Bolt.

To setup the test infrastructure, use `bundle exec rake acceptance:setup`. This will:

* **Provision the master VM**
* **Setup PE on the VM**
* **Setup the mock ServiceNow instance.** This is just a Docker container on the master VM that mimics the relevant ServiceNow endpoints. Its code is contained in `spec/support/acceptance/servicenow`.
* **Install the module on the master**

Each setup step is its own task; `acceptance:setup`'s implementation consists of calling these tasks. Also, all setup tasks are idempotent. That means its safe to run them (and hence `acceptance:setup`) multiple times.

**Note:** You can run the tests on a real ServiceNow instance. To do so, make sure that you've installed the event management plugin in your Servicenow instance, deleted the servicenow portion of your inventory, and set the SN_INSTANCE, SN_USER, and SN_PASSWORD environment variables to appropriate values.

For example...
```
export SN_INSTANCE=dev84270.service-now.com
export SN_PASSWORD='d0hPFGhj5iNU!!!'
export SN_USER=admin  
```

To run the tests after setup, you can do `bundle exec rspec spec/acceptance`. To teardown the infrastructure, do `bundle exec rake acceptance:tear_down`.

Below is an example acceptance test workflow:

```
bundle exec rake acceptance:setup
bundle exec rspec spec/acceptance
bundle exec rake acceptance:tear_down
```

**Note:** Remember to run `bundle exec rake acceptance:install_module` whenever you make updates to the module code. This ensures that the tests run against the latest version of the module.

#### Debugging the acceptance tests
Since the high-level setup is separate from the tests, you should be able to re-run a failed test multiple times via `bundle exec rspec spec/acceptance/path/to/test.rb`.

**Note:** Sometimes, the modules in `spec/fixtures/modules` could be out-of-sync. If you see a weird error related to one of those modules, try running `bundle exec rake spec_prep` to make sure they're updated.
