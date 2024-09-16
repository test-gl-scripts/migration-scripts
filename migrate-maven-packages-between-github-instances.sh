#!/bin/bash

# Usage: ./migrate-maven-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host>
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org`, `repo` scope)
#
# Example: ./migrate-maven-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com

set -e

if [ $# -ne "4" ]; then
    echo "Usage: $0 <source-org> <source-host> <target-org> <target-host>"
    exit 1
fi

# Ensure environment variables are set
if [ -z "$GH_SOURCE_PAT" ]; then
    echo "Error: GH_SOURCE_PAT env var not set"
    exit 1
fi

if [ -z "$GH_TARGET_PAT" ]; then
    echo "Error: GH_TARGET_PAT env var not set"
    exit 1
fi

SOURCE_ORG=$1
SOURCE_HOST=$2
TARGET_ORG=$3
TARGET_HOST=$4

# Create temp dir for storing artifacts
temp_dir=$(mktemp -d)
mkdir -p "$temp_dir/artifacts"

# Check if Python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found"
    exit 1
fi

# Clone mvnfeed-cli if not already done and build it
if [ ! -f "./tool/mvnfeed-cli/.marker" ]; then
    git clone https://github.com/kenmuse/mvnfeed-cli.git ./tool/mvnfeed-cli
    cd ./tool/mvnfeed-cli
    python3 ./scripts/dev_setup.py && touch .marker
    cd $temp_dir
fi

# Base64 encode authentication tokens
auth_source=$(echo -n "user:$GH_SOURCE_PAT" | base64 -w0)
auth_target=$(echo -n "user:$GH_TARGET_PAT" | base64 -w0)

# Fetch all Maven packages from source org
packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=maven" -q '.[] | .name + " " + .repository.name')

# Loop over each package and transfer its versions
echo "$packages" | while IFS= read -r response; do
    package_name=$(echo "$response" | cut -d ' ' -f 1)
    repo_name=$(echo "$response" | cut -d ' ' -f 2)

    echo "Transferring package: $package_name from $repo_name"

    # Configure mvnfeed for source and target repositories
    rm -f ~/.mvnfeed/mvnfeed.ini
    echo "[repository.githubsource]" >> ~/.mvnfeed/mvnfeed.ini
    echo "url = https://maven.pkg.github.com/$SOURCE_ORG/$repo_name" >> ~/.mvnfeed/mvnfeed.ini
    echo "authorization = Basic $auth_source" >> ~/.mvnfeed/mvnfeed.ini
    echo "[repository.githubtarget]" >> ~/.mvnfeed/mvnfeed.ini
    echo "url = https://maven.pkg.github.com/$TARGET_ORG/$repo_name" >> ~/.mvnfeed/mvnfeed.ini
    echo "authorization = Basic $auth_target" >> ~/.mvnfeed/mvnfeed.ini

    mvnfeed config stage_dir set --path "$temp_dir/artifacts"

    # Check if the target repo exists, create it if not
    if ! GH_HOST="$TARGET_HOST" GH_TOKEN=$GH_TARGET_PAT gh api "/repos/$TARGET_ORG/$repo_name" >/dev/null 2>&1; then
        echo "Creating repository: $TARGET_ORG/$repo_name"
        GH_HOST="$TARGET_HOST" GH_TOKEN=$GH_TARGET_PAT gh repo create "$TARGET_ORG/$repo_name" --private 
    fi

    # Fetch all versions of the package from the source
    versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/maven/$package_name/versions" -q '.[] | .name' | sort -V)
    
    for version in $versions; do
        package_group=$(echo "$package_name" | rev | cut -d '.' -f 2- | rev)
        package_artifact=$(echo "$package_name" | rev | cut -d '.' -f 1 | rev)
        echo "Transferring version: $package_group:$package_artifact:$version"
        
        # Use mvnfeed to transfer the artifact
        mvnfeed artifact transfer --from=githubsource --to=githubtarget --name="${package_group}:${package_artifact}:${version}"
    done

    echo "..."

done

# Suggest cleanup to the user
echo "To clean up, run: rm -rf $temp_dir"
