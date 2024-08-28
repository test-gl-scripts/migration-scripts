#!/bin/bash

# Configuration
SOURCE_ORG="cei-training"
DEST_ORG="computerenterprisesinc"
SOURCE_USERNAME=""
DEST_USERNAME=""
SOURCE_PAT=""
DEST_PAT=""
# All Package Tyes
PACKAGE_TYPES=("container" "npm" "maven" "ruby" "nuget" "gradle")

# Log in to Docker with the source and destination credentials
echo "$SOURCE_PAT" | docker login ghcr.io -u "$SOURCE_USERNAME" --password-stdin
echo "$DEST_PAT" | docker login ghcr.io -u "$DEST_USERNAME" --password-stdin

for PACKAGE_TYPE in "${PACKAGE_TYPES[@]}"; do
    PAGE=1
    TOTAL_PAGES=1

    while [ $PAGE -le $TOTAL_PAGES ]; do
        echo "Fetching $PACKAGE_TYPE packages from $SOURCE_ORG (Page $PAGE)..."
        
        RESPONSE=$(curl -s -H "Authorization: token $SOURCE_PAT" \
            "https://api.github.com/orgs/$SOURCE_ORG/packages?package_type=$PACKAGE_TYPE&per_page=100&page=$PAGE")

        if echo "$RESPONSE" | grep -q '"message": "Not Found"'; then
            echo "Error: Not Found for package type $PACKAGE_TYPE. Check your organization or package type."
            break
        fi

        PACKAGES=$(echo "$RESPONSE" | grep -Po '"name": *\K"[^"]*"' | tr -d '"')

        if [ -z "$PACKAGES" ]; then
            echo "No packages found or failed to fetch packages for type $PACKAGE_TYPE."
            break
        fi

        if [ $PAGE -eq 1 ]; then
            TOTAL_PAGES=$(echo "$RESPONSE" | grep -oP '"last_page": *\K[0-9]+' || echo 1)
        fi

        for PACKAGE in $PACKAGES; do
            ENCODED_PACKAGE=$(echo "$PACKAGE" | sed 's/\//%2F/g')

            VERSIONS_JSON=$(curl -s -H "Authorization: token $SOURCE_PAT" \
                "https://api.github.com/orgs/$SOURCE_ORG/packages/$PACKAGE_TYPE/$ENCODED_PACKAGE/versions")

            # echo "Raw JSON response for $PACKAGE: $VERSIONS_JSON"

            if echo "$VERSIONS_JSON" | grep -q '"message": "Not Found"'; then
                echo "Error: Not Found for package $PACKAGE. Check the package name and type."
                continue
            fi

            VERSIONS=$(echo "$VERSIONS_JSON" | jq -r '.[] | select(.metadata != null) | .metadata.container.tags[]' 2>/dev/null)

            if [ -z "$VERSIONS" ]; then
                continue
            fi

            for VERSION in $VERSIONS; do
                if [[ $VERSION == sha256:* ]]; then
                    continue
                fi

                IMAGE="ghcr.io/$SOURCE_ORG/$PACKAGE:$VERSION"
                echo "Pulling $IMAGE"
                docker pull "$IMAGE"

                NEW_IMAGE="ghcr.io/$DEST_ORG/$PACKAGE:$VERSION"
                echo "Tagging $IMAGE as $NEW_IMAGE"
                docker tag "$IMAGE" "$NEW_IMAGE"

                echo "Pushing $NEW_IMAGE"
                docker push "$NEW_IMAGE"
            done
        done

        PAGE=$((PAGE + 1))
    done
done
