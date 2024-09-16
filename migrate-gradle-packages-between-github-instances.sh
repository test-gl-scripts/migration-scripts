#!/bin/bash

# Usage: ./migrate-gradle-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host>

set -e

# Ensure the script is called with exactly 4 arguments
if [ $# -ne "4" ]; then
    echo "Usage: $0 <source-org> <source-host> <target-org> <target-host>"
    exit 1
fi

# Check if GitHub Personal Access Tokens are set
if [ -z "$GH_SOURCE_PAT" ]; then
    echo "Error: set GH_SOURCE_PAT env var"
    exit 1
fi

if [ -z "$GH_TARGET_PAT" ]; then
    echo "Error: set GH_TARGET_PAT env var"
    exit 1
fi

# Assign arguments to variables
SOURCE_ORG=$1
SOURCE_HOST=$2
TARGET_ORG=$3
TARGET_HOST=$4

# Create temporary directories for cloning and storing artifacts
mkdir -p ./temp
cd ./temp
temp_dir=$(pwd)
mkdir -p ./artifacts

# Set up authorization headers for API requests
auth_source="Authorization: token $GH_SOURCE_PAT"
auth_target="Authorization: token $GH_TARGET_PAT"

# Fetch the list of Maven (Gradle) packages from the source organization
packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=maven" -q '.[] | .name + " " + .repository.name')

# Iterate each package
echo "$packages" | while IFS= read -r response; do

  # Extract package name and repository name
  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)

  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"

  # Check if the repository exists in the target organization; if not, create it
  if ! GH_HOST="$TARGET_HOST" GH_TOKEN=$GH_TARGET_PAT gh repo view "$TARGET_ORG/$repo_name" >/dev/null 2>&1
  then
    echo "Creating repo $TARGET_ORG/$repo_name"
    GH_HOST="$TARGET_HOST" gh repo create "$TARGET_ORG/$repo_name" --private
  else
    echo "Repo $TARGET_ORG/$repo_name already exists"
  fi

  # Remove existing directory if it exists
  if [ -d "$repo_name" ]; then
      echo "Removing existing directory $repo_name"
      rm -rf "$repo_name"
  fi

  # Clone the repository from the source organization
  echo "Cloning repo from $SOURCE_ORG/$repo_name"
  git clone "https://$GH_SOURCE_PAT@github.com/$SOURCE_ORG/$repo_name.git"
  
  cd "$repo_name"

  # Update the remote URL to point to the target organization
  echo "Updating remote to point to target organization"
  git remote set-url origin "https://$GH_SOURCE_PAT@$TARGET_HOST/$TARGET_ORG/$repo_name.git"
    
  # Pull latest changes from the target repository if the main branch exists
  if git ls-remote --heads origin main | grep -q 'refs/heads/main'; then
      echo "Pulling latest changes from target repository"
      git pull origin main --rebase
  else
      echo "No main branch exists in the target repository. Skipping pull."
  fi

  # Update build.gradle if it exists
  if [ -f build.gradle ]; then
    echo "Updating build.gradle file to replace all instances of $SOURCE_ORG with $TARGET_ORG"
    sed -i 's|'"$SOURCE_ORG"'|'"$TARGET_ORG"'|g' build.gradle

    # Check if there are any changes in build.gradle
    if git diff --quiet build.gradle; then
        echo "No changes detected in build.gradle. Continuing..."
    else
        echo "Changes detected in build.gradle. Committing and pushing..."
        git add build.gradle
        git commit -m "Update build.gradle to point to $TARGET_ORG"
        git push origin main
    fi
  fi  
  # Update pom.xml if it exists
  if [ -f pom.xml ]; then
    echo "Updating pom.xml file to replace all instances of $SOURCE_ORG with $TARGET_ORG"
    sed -i 's|'"$SOURCE_ORG"'|'"$TARGET_ORG"'|g' pom.xml

    # Check if there are any changes in pom.xml
    if git diff --quiet pom.xml; then
        echo "No changes detected in build.gradle. Continuing..."
    else
        echo "Changes detected in pom.xml. Committing and pushing..."
        git add pom.xml
        git commit -m "Updated pom.xml to point to $TARGET_ORG"
        git push origin main
    fi
  fi  

  # Push to all branches
  git push origin --all
  git push origin --tags
  cd ..
  
  echo "Repo $SOURCE_ORG/$repo_name cloned, build.gradle/pom.xml updated (if found), and pushed to $TARGET_ORG/$repo_name"

  # Fetch Maven/Gradle package versions from the source organization
  echo "Processing Maven/Gradle package versions for $package_name"
  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "orgs/$SOURCE_ORG/packages/maven/$package_name/versions" -q '.[] | .name' | sort -V)
  for version in $versions
  do
    # Determine the package name and version
    echo "   pushing: $package_name:$version"
    
    # Download the Maven/Gradle package from the source organization
    file_name="${package_name}-${version}.jar"

    curl -H "$auth_source" -L -o "${temp_dir}/artifacts/${file_name}" \
      "https://maven.pkg.github.com/${SOURCE_ORG}/$repo_name/$package_name/$version/${file_name}"

    # Upload the Maven/Gradle package to the target organization
    curl -X PUT -H "$auth_target" --data-binary "@${temp_dir}/artifacts/${file_name}" \
      "https://maven.pkg.github.com/$TARGET_ORG/$repo_name/$package_name/$version/${file_name}"

  done

  echo "..."

done

# Clean up temporary files
echo "Run this to clean up your working dir: rm -rf ./temp"
