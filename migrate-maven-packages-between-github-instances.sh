#!/bin/bash

# Usage: ./migrate-maven-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host>

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

# Fetch the list of Maven packages from the source organization
packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=maven" -q '.[] | .name + " " + .repository.name')
echo "Packages response: $packages"
# Check if any packages were fetched
if [ -z "$packages" ]; then
    echo "No packages found in $SOURCE_ORG"
    exit 0
fi

# Iterate each package
echo "$packages" | while IFS= read -r response; do

  # Extract package name and repository name
  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)
  
  # If repo_name is empty, skip
    if [ -z "$repo_name" ]; then
        echo "Repository name is empty for package $package_name, skipping..."
        continue
    fi
    
  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"

  # Check if the repository exists in the target organization; if not, create it
 #  if ! GH_HOST="$TARGET_HOST" GH_TOKEN=$GH_TARGET_PAT gh repo view "$TARGET_ORG/$repo_name" >/dev/null 2>&1
 #  then
 #    echo "Creating repo $TARGET_ORG/$repo_name"
 #    GH_HOST="$TARGET_HOST" gh repo create "$TARGET_ORG/$repo_name" --private
 #  else
 #    echo "Repo $TARGET_ORG/$repo_name already exists"
 #  fi

 #  # Remove existing directory if it exists
 #  if [ -d "$repo_name" ]; then
 #      echo "Removing existing directory $repo_name"
 #      rm -rf "$repo_name"
 #  fi

 #  # Clone the repository from the source organization
 #  echo "Cloning repo from $SOURCE_ORG/$repo_name"  
 #  git clone "https://$GH_SOURCE_PAT@github.com/$SOURCE_ORG/$repo_name.git"

 #  cd "$repo_name"

 #  # Update the remote URL to point to the target organization
 #  echo "Updating remote to point to target organization"
 #  git remote set-url origin "https://$GH_SOURCE_PAT@$TARGET_HOST/$TARGET_ORG/$repo_name.git"

 #  # Pull latest changes from the target repository if the main branch exists
 #  if git ls-remote --heads origin main | grep -q 'refs/heads/main'; then
 #      echo "Pulling latest changes from target repository"
 #      git pull origin main --rebase
 #  else
 #      echo "No main branch exists in the target repository. Skipping pull."
 #  fi
 # git config --global user.name rdesingraj
 # git config --global user.email rdesingraj@ceiamerica.com
 # echo "Git Setup done"

 #  # Update pom.xml if it exists
 #  if [ -f pom.xml ]; then
 #    echo "Updating pom.xml file to replace all instances of $SOURCE_ORG with $TARGET_ORG"
 #    sed -i 's|'"$SOURCE_ORG"'|'"$TARGET_ORG"'|g' pom.xml
 #    if git diff --quiet pom.xml; then
 #        echo "No changes in pom.xml, skipping commit."
 #    else    
 #        # Stage and Commit the pom.xml
 #        git add pom.xml
 #        git commit -m "Update pom.xml to point to TARGET_ORG"
 #        # Push changes to the main branch
 #        git push origin main
 #        git push origin --tags
 #    fi
 #  else
 #    echo "pom.xml file not found in the repo $repo_name"
 #  fi

 #  # Push to all branches
 #  git push origin --all
 #  cd ..

 #  echo "Repo $SOURCE_ORG/$repo_name cloned, pom.xml updated (if found), and pushed to $TARGET_ORG/$repo_name"

  # Fetch Maven package versions from the source organization
  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "orgs/$SOURCE_ORG/packages/maven/$package_name/versions" -q '.[] | .name' | sort -V)
  for version in $versions
  do
    # Determine the package group and artifact names
    package_group=$(echo "$package_name" | awk -F'.' '{OFS="."; $NF=""; print substr($0,1,length($0)-1)}')
    package_artifact=$(echo "$package_name" | awk -F'.' '{print $NF}')

    name=$(echo $package_group:$package_artifact:$version)
    echo "   downloading: $name"

    # Download the Maven package from the source organization
    curl -H "$auth_source" -L -o "${temp_dir}/artifacts/${package_artifact}-${version}.jar" \
      "https://maven.pkg.github.com/${SOURCE_ORG}/download/${package_group}/${package_artifact}/${version}/${package_artifact}-${version}.jar"
    ls -lt
    # Check if the file was created successfully
    if [ ! -f "${temp_dir}/artifacts/${package_artifact}-${version}.jar" ]; then
    echo "Warning: Failed to create the file ${temp_dir}/artifacts/${package_artifact}-${version}.jar"
    continue
    fi
    
    echo "   pushing: $name"
    echo "Uploading to: $upload_url"# Define variables
    upload_url="https://maven.pkg.github.com/$TARGET_ORG/$repo_name/${package_group}/${package_artifact}/${version}/${package_artifact}-${version}.jar"

# Upload the Maven package to the target organization
    
    response=$(curl -X PUT -H "Authorization: token $GH_TARGET_PAT" \
  -H "Content-Type: application/java-archive" \
  --data-binary "@${temp_dir}/artifacts/${package_artifact}-${version}.jar" \
  "$upload_url" -w "%{http_code}" -o response.log -s)

    echo "Upload response: $response"
    cat response.log
 
    if [ "$response" -ne 200 ]; then
        echo "Upload failed with HTTP status code $response. Check the URL and repository setup."
    else
        echo "Version got pushed...${package_artifact}-${version}"
    fi
  done

  echo "..."

done

# Clean up temporary files
echo "Run this to clean up your working dir: rm -rf ./temp"
