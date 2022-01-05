# Maintaining the CHANGELOG

With each PR add your change to the appropriate section of the change log, which can be any of the `Types of changes` spelled out at the bottom of the [keep a changelog] format website.

Each entry should have one of the following formats:

- Normal ticketed work

  \- Pull Request Title Minus The Ticket Number \[#\<PR Number\>\] - \(\[PIE-1234\]\)

  You would then add links to the reference links section at the bottom of the changelog like:

  \[PIE-1234\]: https://tickets.puppetlabs.com/browse/PIE-1234

  \[#\<PR Number\>\]: https://github.com/puppetlabs/puppetlabs-servicenow_reporting_integration/pull/\<PR Number\>

- For community contributions

  Same as above, but if there is not ticket, then link instead to the issue if that exists, or only the PR if that is the only context. You can also optionally add a thanks to the community contributor and link to their github bio page, again via reference style linking.

# Releasing the module

# Releasing the module

Run a `release_prep` job with the branch set to `main` and `module_version` set to the module version that will be released

> You can access the `release_prep` job via the `Actions` tab at the repository home page

The `release_prep` job will run the `pdk release prep` command, push its changes up to the `release_prep` branch on the repo, and then generate a PR against `main` for review. Follow the instructions in the PR body to properly update the `CHANGELOG.md` file.

Once the release prep PR's been merged to `main`, run a `release` job with the branch set to `main`. The `release` job will tag the module at the current `metadata.json` version, push the tag upstream, then build and publish the module to the Forge.

<!-- Reference Links Section -->

[keep a changelog]: https://keepachangelog.com/en/1.0.0/
