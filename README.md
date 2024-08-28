# GitHub Packages Migration Script

## Overview

This script automates the migration of container images and other package types from one GitHub organization to another. It supports various package types such as Docker (containers), npm, Maven, RubyGems, NuGet, and Gradle. The script fetches all packages and their versions from the source organization, re-tags them for the destination organization, and then pushes them to the destination GitHub Packages registry.

## Features

- **Multi-Package Type Support:** Handles multiple GitHub package types including Docker, npm, Maven, RubyGems, NuGet, and Gradle.
- **Pagination Support:** Handles pagination to ensure all packages and versions are processed.
- **Docker Login Automation:** Logs into Docker with provided credentials for both the source and destination organizations.
- **Error Handling:** Includes basic error handling to skip problematic versions and packages.

## Prerequisites

- **Docker:** Make sure Docker is installed and running on your machine.
- **GitHub CLI (`gh`):** Ensure you have access to the GitHub CLI for token management.
- **GitHub Personal Access Tokens (PAT):** Generate Personal Access Tokens for both source and destination organizations with appropriate permissions (e.g., `packages:read`, `packages:write`, `repo`).

## Setup

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/your-username/github-packages-migration.git
   cd github-packages-migration
   
2. **Set Environment Variables:**

    Update the following environment variables with your credentials and organization details:
    ```bash
    export SOURCE_PAT="your-source-org-pat"
    export SOURCE_USERNAME="your-source-org-username"
    export SOURCE_ORG="your-source-org"
    export DEST_PAT="your-destination-org-pat"
    export DEST_USERNAME="your-destination-org-username"
    export DEST_ORG="your-destination-org"

3. **Set Environment Variables:**
    Ensure you have jq installed. For example, on Debian-based systems, you can install it using:

## Usage

1. **Run the Migration Script:**
   Execute the script to start the migration process:

   ```bash
   git clone https://github.com/your-username/github-packages-migration.git
   cd github-packages-migration
   
3. **Monitor Progress:**

    The script will output progress messages, including information about package processing, version fetching, image pulling, tagging, and pushing.

 
## Error Handling

1. **Invalid Reference Format:**
   EEnsure that the package names and versions are correctly formatted.

2. **No Versions Found**
     Verify that the package exists in the source organization and has versions available.

3. **Network Issues:**
    Check your internet connection and GitHub API rate limits.

  
## Contributing
  Feel free to submit issues and pull requests if you find bugs or have suggestions for improvements.
  
## License
  This project is licensed under the MIT License. See the LICENSE file for details.
   
```bash
Feel free to customize the details, such as repository URLs, organization names, and PATs, according to your specific setup.


