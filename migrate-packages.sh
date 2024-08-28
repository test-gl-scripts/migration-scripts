#!/bin/bash

# Configuration
SOURCE_ORG="cei-training"
DEST_ORG="computerenterprisesinc"
SOURCE_USERNAME=""
DEST_USERNAME=""
SOURCE_PAT=""
DEST_PAT=""

PER_PAGE=100
PAGE=1
PACKAGES_FETCHED=0
TOTAL_PAGES=1

while [ $PAGE -le $TOTAL_PAGES ]; do
    echo "Fetching packages from $SOURCE_ORG (Page $PAGE)..."
    RESPONSE=$(curl -s -H "Authorization: token $SOURCE_PAT" \
        "https://api.github.com/orgs/$SOURCE_ORG/packages?package_type=container&per_page=$PER_PAGE&page=$PAGE")
    
    PACKAGES=$(echo "$RESPONSE" | grep -Po '"name": *\K"[^"]*"' | tr -d '"')

    if [ -z "$PACKAGES" ]; then
        echo "No packages found or failed to fetch packages."
        break
    fi

    if [ $PAGE -eq 1 ]; then
        TOTAL_PAGES=$(echo "$RESPONSE" | grep -oP '"last_page": *\K[0-9]+' || echo 1)
    fi

    for PACKAGE in $PACKAGES; do
        ENCODED_PACKAGE=$(echo "$PACKAGE" | sed 's/\//%2F/g')
        echo "Processing package: $ENCODED_PACKAGE"

        VERSIONS_JSON=$(curl -s -H "Authorization: token $SOURCE_PAT" \
            "https://api.github.com/orgs/$SOURCE_ORG/packages/container/$ENCODED_PACKAGE/versions")

        if [ -z "$VERSIONS_JSON" ]; then
            echo "No versions found or failed to fetch versions for package $PACKAGE."
            continue
        fi

        VERSIONS=$(echo "$VERSIONS_JSON" | jq -r '.[] | select(.metadata != null) | .metadata.container.tags[]' 2>/dev/null)

        if [ -z "$VERSIONS" ]; then
            echo "No versions found or failed to fetch versions for package $PACKAGE."
            continue
        fi

        for VERSION in $VERSIONS; do
            if [[ $VERSION == sha256:* ]]; then
                echo "Skipping digest format for $PACKAGE:$VERSION"
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
