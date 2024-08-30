# GitHub Packages Migration Script

## Overview

This script automates the migration of container images and other package types from one GitHub organization to another. It supports various package types, including:

- Docker Container Images
- npm Packages
- Maven Packages
- Ruby Gems
- NuGet Packages
- Gradle Packages
  
The script fetches all packages and their versions from the source organization, re-tags them for the destination organization, and then pushes them to the destination GitHub Packages registry.

## Features

- **Multi-Package Type Support:** Handles multiple GitHub package types including Docker, npm, Maven, RubyGems, NuGet, and Gradle.
- **Pagination Support:** Handles pagination to ensure all packages and versions are processed.
- **Docker Login Automation:** Logs into Docker with provided credentials for both the source and destination organizations.
- **Error Handling:** Includes basic error handling to skip problematic versions and packages.

## Prerequisites

Ensure the following tools are installed and properly configured on your machine:

- **Docker:** Make sure Docker is installed and running on your machine.
- **GitHub CLI (`gh`):** Ensure you have access to the GitHub CLI for token management.
- **GitHub Personal Access Tokens (PAT):** Generate Personal Access Tokens for both source and destination organizations with appropriate permissions (e.g., `packages:read`, `packages:write`, `repo`).
- npm
- Maven
- Ruby (with `gem`)
- NuGet CLI
- Gradle

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
## Script Description

The script performs the following actions:

1. **Logs into Docker** using source and destination credentials.
2. **Fetches packages** from the source organization for each supported package type.
3. **Processes each package** based on its type and migrates it to the destination organization.

### Docker Container Images

- **Pulls** the container image from the source organization.
- **Tags** the image for the destination organization.
- **Pushes** the tagged image to the destination organization.

### npm Packages

- **Downloads** each npm package version from the source organization.
- **Publishes** the package to the destination organization.

### Maven Packages

- **Downloads** each Maven package version from the source organization.
- **Uploads** the package to the destination organization.

### Ruby Gems

- **Downloads** each Ruby gem version from the source organization.
- **Pushes** the gem to the destination organization.

### NuGet Packages

- **Downloads** each NuGet package version from the source organization.
- **Uploads** the package to the destination organization.

### Gradle Packages

- **Downloads** each Gradle package version from the source organization.
- **Uploads** the package to the destination organization.
  
## Usage

1. **Clone the Repository (or download the script):**
   
   ```bash
   git clone https://github.com/your-username/github-packages-migration.git
   cd github-packages-migration

2. **Set the Required Environment Variables:**
   Set the environment variables as shown above.

3. **Run the Script:**
   ```bash
   ./migrate_packages.sh
   
4. **Monitor Progress:**
    The script will output progress messages, including information about package processing, version fetching, image pulling, tagging, and pushing.
 
## Troubleshooting (Error Handling)
If you encounter issues, check the following:

1. **Environment Variables:**
   Ensure all required environment variables are set correctly.
   
3. **Permissions:**
   Verify that the Personal Access Tokens have the necessary scopes and permissions.
   
5. **Dependencies:**
    Ensure all required tools are installed and available in your PATH.
   
7. **Invalid Reference Format:**
   Ensure that the package names and versions are correctly formatted.

8. **No Versions Found**
     Verify that the package exists in the source organization and has versions available.

9. **Network Issues:**
    Check your internet connection and GitHub API rate limits.

   
## Notes
If you encounter issues, check the following:

1. **Windows Compatibility:**
   This script assumes a Unix-like environment (Linux or macOS). If you're using Windows, ensure that you adjust commands (rm for directory removal, for example) accordingly.
   
3. **Package Availability:**
   If no packages are found for a particular type or organization, the script will report it but continue to process other package types.
   
5. **Security:**
    Handle GitHub PATs securely and ensure they have appropriate permissions for package access and modification.
  
## Contributing
  Feel free to submit issues and pull requests if you find bugs or have suggestions for improvements.
  
## License
  This project is licensed under the MIT License. See the LICENSE file for details.
   
```bash
Feel free to customize the details, such as repository URLs, organization names, and PATs, according to your specific setup.


