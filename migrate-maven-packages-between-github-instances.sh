#!/bin/bash

# Define your variables
TARGET_ORG="computerenterprisesinc"
repo_name="maven-sample"
temp_dir="./temp"
GH_TARGET_PAT="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"
GH_SOURCE_PAT="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"

# Create temp directories if they don't exist
mkdir -p "${artifacts_dir}"

# Example package details (replace with your actual logic for these values)
package_group="com.cei"
package_artifact="maven-package"
versions=("0.0.1-SNAPSHOT" "0.1.1-SNAPSHOT" "5.1.1-SNAPSHOT")



for version in "${versions[@]}"; do
    echo "   downloading: $package_group:$package_artifact:$version"

    # Download the Maven package from the source organization
    curl -H "Authorization: token $GH_SOURCE_PAT" -L -o "${artifacts_dir}/${package_artifact}-${version}.jar" \
      "https://maven.pkg.github.com/$SOURCE_ORG/$repo_name/${package_group}/${package_artifact}/${version}/${package_artifact}-${version}.jar"

    # Check if the file was created successfully
    if [ ! -f "${artifacts_dir}/${package_artifact}-${version}.jar" ]; then
        echo "Warning: Failed to create the file ${artifacts_dir}/${package_artifact}-${version}.jar"
        continue
    fi

    echo "   pushing: $package_group:$package_artifact:$version"
    
    upload_url="https://maven.pkg.github.com/$TARGET_ORG/$repo_name/${package_group}/${package_artifact}/${version}/${package_artifact}-${version}.jar"
    echo "Uploading to: $upload_url"
    
    # Upload the Maven package to the target organization
    response=$(curl -X PUT -H "Authorization: token $GH_TARGET_PAT" \
                  -H "Content-Type: application/java-archive" \
                  --data-binary "@${artifacts_dir}/${package_artifact}-${version}.jar" \
                  "$upload_url" -w "%{http_code}" -o /dev/null -s)
    
    if [ "$response" -ne 200 ]; then
        echo "Upload failed with HTTP status code $response. Check the URL and repository setup."
        echo "URL: $upload_url"
        echo "File: ${artifacts_dir}/${package_artifact}-${version}.jar"
    else
        echo "Version got pushed...${package_artifact}-${version}"
    fi
done

# Clean up temporary files
echo "Run this to clean up your working dir: rm -rf ./temp"
