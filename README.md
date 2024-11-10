Here’s the updated README with the MIT license:

# Ruby Upgrade Action

[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Ruby Upgrade Action** is a GitHub Action that automatically upgrades the Ruby version in your repository. It updates the Ruby version in `.ruby-version`, `Gemfile`, `Dockerfile`, and GitHub Actions workflows. This action can be easily reused across multiple projects, simplifying the process of keeping Ruby dependencies up to date.

## Features

- Automatically detects the latest stable Ruby version.
- Updates Ruby version in:
  - `.ruby-version`
  - `Gemfile` (if the Ruby version is specified)
  - `Dockerfile` (if using `ruby:*` base image)
  - GitHub Actions workflows (using `ruby-version`)
- Runs tests after upgrading Ruby to ensure compatibility.
- Creates a pull request with the changes.

## Prerequisites

This action requires:

- A repository using Ruby with a `.ruby-version`, `Gemfile`, and optionally a `Dockerfile`.
- GitHub token (automatically provided by GitHub Actions as `GITHUB_TOKEN`).

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
  upgrade:
    runs-on: ubuntu-latest
    steps:
      - name: Run Ruby Upgrade Action
        uses: andrew/ruby-upgrade-action@main
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

Input	Description	Required	Default
repo-token	GitHub token for creating commits and pull requests.	true	N/A
ruby-base-image	Base image for Dockerfile (e.g., ruby:*-alpine).	false	ruby:*-alpine

## Outputs

Output	Description
latest-version	The latest Ruby version detected

## Example

This action will:
	1.	Fetch the latest Ruby version from the Ruby website.
	2.	Update .ruby-version, Gemfile, Dockerfile, and GitHub Actions YAML files.
	3.	Run bundle install and execute the test suite.
	4.	Commit the changes and open a pull request.

## Customization

If your repository has a different structure or additional files that specify the Ruby version, you can modify the update_files.sh script in your fork of this action.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.
