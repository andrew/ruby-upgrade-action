# Ruby Upgrade Action

[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Ruby Upgrade Action** is a GitHub Action that automatically upgrades the Ruby version in your repository. It updates the Ruby version in `.ruby-version`, `.tool-versions`, `Gemfile`, `Gemfile.lock` and `Dockerfile`. This action can be easily reused across multiple projects, simplifying the process of keeping Ruby dependencies up to date.

## Features

- Automatically detects the latest stable Ruby version.
- Updates Ruby version in:
  - `.ruby-version`
  - `Gemfile` (if the Ruby version is specified)
  - `Dockerfile` (if using `ruby:*` base image)
- Runs tests after upgrading Ruby to ensure compatibility.
- Creates a pull request with the changes.

## Prerequisites

This action requires:

- A repository using Ruby with a `.ruby-version` or `.tool-versions`, `Gemfile`, and optionally a `Dockerfile`.
- GitHub token (automatically provided by GitHub Actions as `GITHUB_TOKEN`).
- Repository setting: "Allow GitHub Actions to create and approve pull requests" must be enabled in Settings → Actions → General → Workflow permissions.

## Usage

Add the following workflow to your repository to use this action:

```yaml
# .github/workflows/upgrade-ruby.yml
name: Upgrade Ruby

on:
  workflow_dispatch:
  schedule:
    - cron: "0 0 * * 0" # Runs weekly

permissions:
  contents: write
  pull-requests: write

jobs:
  upgrade-ruby:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: andrew/ruby-upgrade-action@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

This workflow runs weekly and can also be triggered manually. You can customize the schedule by modifying the cron expression.

## Example

This action will:

1. Fetch the latest Ruby version from the Ruby website.
2. Update .ruby-version, Gemfile, Dockerfile, and GitHub Actions YAML files.
3. Run bundle install and execute the test suite.
4. Commit the changes and open a pull request.

## Customization

If your repository has a different structure or additional files that specify the Ruby version, you can modify the update_files.sh script in your fork of this action.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.
