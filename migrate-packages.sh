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

echo $SOURCE_PAT | gh auth login --with-token
echo $DEST_PAT | gh auth login --with-token

copy_container_package() {
    local PACKAGE=$1
    local VERSION=$2
    if [[ $VERSION == sha256:* ]]; then
        echo "Skipping digest format for $PACKAGE:$VERSION"
        return
    fi
    IMAGE="ghcr.io/$SOURCE_ORG/$PACKAGE:$VERSION"
    echo "Pulling $IMAGE"
    docker pull "$IMAGE"
    NEW_IMAGE="ghcr.io/$DEST_ORG/$PACKAGE:$VERSION"
    echo "Tagging $IMAGE as $NEW_IMAGE"
    docker tag "$IMAGE" "$NEW_IMAGE"
    echo "Pushing $NEW_IMAGE"
    docker push "$NEW_IMAGE"
}

copy_npm_package() {
    local PACKAGE=$1
    local VERSION=$2
    echo "Packing $PACKAGE@$VERSION..."
    npm pack "@$SOURCE_ORG/$PACKAGE@$VERSION" --registry "https://npm.pkg.github.com"
    if [ $? -ne 0 ]; then
        echo "npm pack failed for $PACKAGE@$VERSION."
        return 1
    fi
    TAR_FILE=$(find . -maxdepth 1 -type f -name "*$PACKAGE-$VERSION*.tgz" -print -quit)
    if [ -z "$TAR_FILE" ]; then
        echo "Failed to create tarball for $PACKAGE@$VERSION."
        return 1
    fi
    echo "Publishing $PACKAGE@$VERSION to $DEST_ORG..."
    npm publish --registry "https://npm.pkg.github.com/$DEST_ORG" "$TAR_FILE"
    if [ $? -ne 0 ]; then
        echo "npm publish failed for $PACKAGE@$VERSION."
        return 1
    fi
}

# TODO: Validate
copy_maven_package() {
    local PACKAGE=$1
    local VERSIONS_JSON=$2
    VERSIONS=$(echo "$VERSIONS_RESPONSE" | jq -r '.[] | .name' 2>/dev/null)
    if [ -z "$VERSIONS" ]; then
        echo "No versions found or failed to fetch versions for package $PACKAGE."
        return
    fi
    for VERSION in $VERSIONS; do
        echo "Fetching artifact for $PACKAGE@$VERSION..."
        ARTIFACT_URL=$(curl -s -H "Authorization: token $SOURCE_PAT" \
            "https://api.github.com/orgs/$SOURCE_ORG/packages/maven/$PACKAGE/versions/$VERSION" | jq -r '.dist.tarball')
        if [ -z "$ARTIFACT_URL" ]; then
            echo "No artifact found for $PACKAGE@$VERSION."
            continue
        fi
        echo "Downloading artifact from $ARTIFACT_URL..."
        curl -s -L -H "Authorization: token $SOURCE_PAT" -o "$PACKAGE-$VERSION.jar" "$ARTIFACT_URL"
        echo "Publishing $PACKAGE@$VERSION to $DEST_ORG..."
        # TODO: Use a Maven command to publish the artifact to the destination organization (details would depend on Maven setup)
        # groupId (customize for our orgs):
        mvn deploy:deploy-file -DgroupId=your.groupId -DartifactId=$PACKAGE -Dversion=$VERSION -Dpackaging=jar -Dfile="$PACKAGE-$VERSION.jar" -Durl=https://maven.pkg.github.com/$DEST_ORG
        echo "Cleaning up $PACKAGE-$VERSION.jar..."
        rm "$PACKAGE-$VERSION.jar"
    done
}

# TODO: Validate
copy_ruby_package() {
    local PACKAGE=$1
    local VERSIONS_JSON=$2
    VERSIONS=$(echo "$VERSIONS_RESPONSE" | jq -r '.[] | .name' 2>/dev/null)
    if [ -z "$VERSIONS" ]; then
        echo "No versions found or failed to fetch versions for package $PACKAGE."
        return
    fi
    for VERSION in $VERSIONS; do
        echo "Fetching gem for $PACKAGE@$VERSION..."
        GEM_URL=$(curl -s -H "Authorization: token $SOURCE_PAT" \
            "https://api.github.com/orgs/$SOURCE_ORG/packages/ruby/$PACKAGE/versions/$VERSION" | jq -r '.dist.tarball')
        if [ -z "$GEM_URL" ]; then
            echo "No gem found for $PACKAGE@$VERSION."
            continue
        fi
        echo "Downloading gem from $GEM_URL..."
        curl -s -L -H "Authorization: token $SOURCE_PAT" -o "$PACKAGE-$VERSION.gem" "$GEM_URL"
        echo "Publishing $PACKAGE@$VERSION to $DEST_ORG..."
        gem push --host https://rubygems.pkg.github.com/$DEST_ORG "$PACKAGE-$VERSION.gem"
        echo "Cleaning up $PACKAGE-$VERSION.gem..."
        rm "$PACKAGE-$VERSION.gem"
    done
}

copy_nuget_package() {
    local PACKAGE=$1
    local VERSIONS_JSON=$2
    echo "Fetching nupkg for $PACKAGE@$VERSION..."
    url="https://nuget.pkg.github.com/$SOURCE_ORG/download/$PACKAGE/$VERSION/$PACKAGE.$VERSION.nupkg"

    if [ -z "$url" ]; then
        echo "No nupkg found for $PACKAGE@$VERSION."
        return
    fi
    echo "Downloading nupkg from $url..."
    curl -s -L -H "Authorization: token $SOURCE_PAT" -o "$PACKAGE-$VERSION.nupkg" "$url"
    echo "Publishing $PACKAGE@$VERSION to $DEST_ORG..."
#    nuget setApiKey $DEST_PAT -Source "https://nuget.pkg.github.com/$DEST_ORG/index.json"
    dotnet nuget push $PACKAGE-$VERSION.nupkg --source "https://nuget.pkg.github.com/$DEST_ORG/index.json" --api-key $DEST_PAT

    echo "Cleaning up $PACKAGE-$VERSION.nupkg..."
    rm "$PACKAGE-$VERSION.nupkg"
}

# TODO: Validate
copy_gradle_package() {
    local PACKAGE=$1
    local VERSIONS_JSON=$2
    VERSIONS=$(echo "$VERSIONS_RESPONSE" | jq -r '.[] | .name' 2>/dev/null)
    if [ -z "$VERSIONS" ]; then
        echo "No versions found or failed to fetch versions for package $PACKAGE."
        return
    fi
    for VERSION in $VERSIONS; do
        echo "Fetching artifact for $PACKAGE@$VERSION..."
        ARTIFACT_URL=$(curl -s -H "Authorization: token $SOURCE_PAT" \
            "https://api.github.com/orgs/$SOURCE_ORG/packages/gradle/$PACKAGE/versions/$VERSION" | jq -r '.dist.tarball')
        if [ -z "$ARTIFACT_URL" ]; then
            echo "No artifact found for $PACKAGE@$VERSION."
            continue
        fi
        echo "Downloading artifact from $ARTIFACT_URL..."
        curl -s -L -H "Authorization: token $SOURCE_PAT" -o "$PACKAGE-$VERSION.jar" "$ARTIFACT_URL"
        echo "Publishing $PACKAGE@$VERSION to $DEST_ORG..."
        # TODO: Use a Gradle command to publish the artifact to the destination organization
        # groupId (for our orgs):
        ./gradlew publish -PgroupId=your.groupId -PartifactId=$PACKAGE -Pversion=$VERSION -Ppackaging=jar -Pfile="$PACKAGE-$VERSION.jar" -Durl=https://gradle.pkg.github.com/$DEST_ORG
        echo "Cleaning up $PACKAGE-$VERSION.jar..."
        rm "$PACKAGE-$VERSION.jar"
    done
}

# TODO: Validate
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
            TOTAL_PAGES=$(echo "$RESPONSE" | grep -i 'rel="last"' | grep -oP 'page=\K\d+')
            TOTAL_PAGES=${TOTAL_PAGES:-1}
        fi
        for PACKAGE in $PACKAGES; do
            echo "Fetching versions for package $PACKAGE..."
            ENCODED_PACKAGE=$(echo "$PACKAGE" | sed 's/\//%2F/g')
            VERSIONS_RESPONSE=$(gh api -H "Accept: application/vnd.github.v3+json" orgs/$SOURCE_ORG/packages/$PACKAGE_TYPE/$ENCODED_PACKAGE/versions)
            if [ $? -ne 0 ]; then
                echo "Failed to fetch versions for $PACKAGE."
                continue
            fi
            case $PACKAGE_TYPE in
                container)
                    VERSIONS=$(echo "$VERSIONS_RESPONSE" | jq -r '.[] | select(.metadata != null) | .metadata.container.tags[]' 2>/dev/null)
                    for VERSION in $VERSIONS; do
                        copy_container_package "$PACKAGE" "$VERSION"
                    done
                    ;;
                npm)
                    VERSIONS=$(echo "$VERSIONS_RESPONSE" | jq -r '.[] | .name')
                    for VERSION in $VERSIONS; do
                        copy_npm_package "$PACKAGE" "$VERSION"
                    done
                    ;;
                maven)
                    copy_maven_package "$PACKAGE" "$VERSIONS_RESPONSE"
                    ;;
                ruby)
                    copy_ruby_package "$PACKAGE" "$VERSIONS_RESPONSE"
                    ;;
                nuget)
                    VERSIONS=$(echo "$VERSIONS_RESPONSE" | jq -r '.[] | .name')
                    for VERSION in $VERSIONS; do
                        copy_nuget_package "$PACKAGE" "$VERSION"
                    done
                    ;;
                gradle)
                    copy_gradle_package "$PACKAGE" "$VERSIONS_RESPONSE"
                    ;;
                *)
                    echo "Unsupported package type: $PACKAGE_TYPE"
                    ;;
            esac
        done
        PAGE=$((PAGE + 1))
    done
done
