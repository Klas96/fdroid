#!/bin/bash

# --- Ensure script is run with Bash ---
if [ -z "$BASH_VERSION" ]; then
  echo "❌ This script must be run with bash, not sh."
  echo "   Try: bash $0 ... or make it executable and run ./$0 ..."
  exit 1
fi

# ContentCreator F-Droid Release Script
# This script is specifically for releasing ContentCreator to F-Droid.
# The F-Droid client should point to: https://klas96.github.io/fdroid/repo
# Run this from the project root directory

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTENT_CREATOR_DIR="$PROJECT_ROOT/content-creator-app"
FLUTTER_APP_DIR="$CONTENT_CREATOR_DIR/flutter-app"
FDROID_DIR="$PROJECT_ROOT/fdroid"
LOG_FILE="$PROJECT_ROOT/fdroid/logs/release-$(date +%Y%m%d-%H%M%S).log"

# Load .env file from fdroid directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
fi

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/fdroid/logs"

# App-specific configuration
APP_ID="${APP_ID:?APP_ID not set in .env}"  # New app ID for content creator
APP_NAME="${APP_NAME:?APP_NAME not set in .env}"
APP_DESCRIPTION="${APP_DESCRIPTION:?APP_DESCRIPTION not set in .env}"
APP_CATEGORIES="${APP_CATEGORIES:?APP_CATEGORIES not set in .env}"
APP_WEBSITE="${APP_WEBSITE:?APP_WEBSITE not set in .env}"
APP_SOURCE_CODE="${APP_SOURCE_CODE:?APP_SOURCE_CODE not set in .env}"
APP_ISSUE_TRACKER="${APP_ISSUE_TRACKER:?APP_ISSUE_TRACKER not set in .env}"
APP_DONATE="${APP_DONATE:?APP_DONATE not set in .env}"
APP_CHANGELOG="${APP_CHANGELOG:?APP_CHANGELOG not set in .env}"
APP_REPO="${APP_REPO:?APP_REPO not set in .env}"
APP_SUBDIR="${APP_SUBDIR:?APP_SUBDIR not set in .env}"

# Script options
DRY_RUN=false
SKIP_TESTS=false
SKIP_BUILD=false
FORCE=false
VERBOSE=false
SHOW_FINGERPRINT=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️  $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ $1" >> "$LOG_FILE"
}

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 📋 $1" >> "$LOG_FILE"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}🔍 $1${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 $1" >> "$LOG_FILE"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check for repository version conflicts
check_repository_conflicts() {
    print_verbose "Checking for repository version conflicts for $APP_NAME..."
    
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    
    # Check this app's repository metadata file
    local metadata_file="$FDROID_DIR/metadata/${APP_ID}.yml"
    
    if [ -f "$metadata_file" ]; then
        local file_version=$(grep "CurrentVersion:" "$metadata_file" | sed 's/.*CurrentVersion: //')
        local file_code=$(grep "CurrentVersionCode:" "$metadata_file" | sed 's/.*CurrentVersionCode: //')
        
        if [ "$file_version" != "$version_name" ] || [ "$file_code" != "$version_code" ]; then
            print_warning "Repository version mismatch for $APP_NAME in $metadata_file: version $file_version ($file_code) != $version_name ($version_code)"
            print_verbose "The script will update the repository to match the current version."
        else
            print_verbose "Repository version is up to date for $APP_NAME."
        fi
    else
        print_verbose "Creating new metadata file for $APP_NAME ($APP_ID)"
    fi
    
    # Check for other apps in repository
    print_verbose "Checking for other apps in repository..."
    local other_apps=()
    for other_metadata in "$FDROID_DIR/metadata"/*.yml; do
        if [ -f "$other_metadata" ] && [ "$(basename "$other_metadata")" != "${APP_ID}.yml" ]; then
            local other_app_name=$(grep "AutoName:" "$other_metadata" | sed 's/AutoName: //')
            local other_app_id=$(basename "$other_metadata" .yml)
            other_apps+=("$other_app_name ($other_app_id)")
            print_verbose "Found other app: $other_app_name ($other_app_id)"
        fi
    done
    
    if [ ${#other_apps[@]} -gt 0 ]; then
        print_status "Other apps in repository: ${other_apps[*]}"
        print_verbose "These apps will be preserved during the release process."
    fi
}

# Function to validate environment
validate_environment() {
    print_step "Validating environment..."
    
    # Check required directories
    if [ ! -d "$CONTENT_CREATOR_DIR" ]; then
        print_error "Could not find content-creator-app directory. Run this script from the project root."
        exit 1
    fi

    if [ ! -d "$FLUTTER_APP_DIR" ]; then
        print_error "Could not find flutter-app directory at $FLUTTER_APP_DIR"
        exit 1
    fi

    if [ ! -d "$FDROID_DIR" ]; then
        print_error "Could not find fdroid directory at $FDROID_DIR"
        exit 1
    fi

    # Check required commands
    local missing_commands=()
    
    if ! command_exists flutter; then
        missing_commands+=("flutter")
    fi
    
    if ! command_exists git; then
        missing_commands+=("git")
    fi
    
    if ! command_exists fdroid; then
        missing_commands+=("fdroid")
    fi
    
    if ! command_exists jarsigner; then
        missing_commands+=("jarsigner")
    fi

    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        echo "Please install the missing dependencies:"
        for cmd in "${missing_commands[@]}"; do
            case $cmd in
                flutter)
                    echo "  - Flutter: https://flutter.dev/docs/get-started/install"
                    ;;
                fdroid)
                    echo "  - fdroidserver: pip install fdroidserver"
                    ;;
                jarsigner)
                    echo "  - Java JDK: sudo apt install openjdk-11-jdk"
                    ;;
            esac
        done
        exit 1
    fi

    # Check Flutter version
    local flutter_version=$(flutter --version | grep -o "Flutter [0-9.]*" | cut -d' ' -f2)
    print_verbose "Flutter version: $flutter_version"
    
    # Check if content-creator-app directory is a git repository
    if [ ! -d "$CONTENT_CREATOR_DIR/.git" ]; then
        print_error "content-creator-app directory is not a git repository."
        print_error "Please initialize git in the content-creator-app directory:"
        print_error "  cd content-creator-app && git init && git add . && git commit -m 'Initial commit'"
        exit 1
    fi
    
    # Check if F-Droid directory is a git repository
    if [ ! -d "$FDROID_DIR/.git" ]; then
        print_error "fdroid directory is not a git repository."
        print_error "Please initialize git in the fdroid directory:"
        print_error "  cd fdroid && git init && git add . && git commit -m 'Initial commit'"
        exit 1
    fi

    # Check for uncommitted changes in content-creator-app
    if [ "$FORCE" != true ] && [ "$DRY_RUN" != true ]; then
        cd "$CONTENT_CREATOR_DIR"
        if ! git diff-index --quiet HEAD --; then
            print_warning "You have uncommitted changes in content-creator-app. Consider committing them first."
            if [ "$FORCE" != true ]; then
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    print_error "Aborted by user."
                    exit 1
                fi
            fi
        fi
    fi

    print_status "Environment validation passed"
}

# Function to get current version info
get_current_version() {
    cd "$FLUTTER_APP_DIR"
    local version_name=$(grep "versionName" android/app/build.gradle | sed 's/.*versionName = "\(.*\)".*/\1/')
    local version_code=$(grep "versionCode" android/app/build.gradle | sed 's/.*versionCode = \([0-9]*\).*/\1/')
    echo "$version_name:$version_code"
}

# Function to update version
update_version() {
    local new_version=$1
    local new_version_code=$2
    
    print_step "Updating version to $new_version (Code: $new_version_code)..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would update version to $new_version ($new_version_code)"
        return
    fi
    
    cd "$FLUTTER_APP_DIR"
    
    # Update version using the existing script if it exists
    if [ -f "scripts/update-version.sh" ]; then
        if [ $# -eq 2 ]; then
            ./scripts/update-version.sh "$new_version" "$new_version_code"
        else
            ./scripts/update-version.sh "$new_version"
        fi
    else
        # Manual version update
        if [ $# -eq 2 ]; then
            sed -i "s/versionName = \".*\"/versionName = \"$new_version\"/" android/app/build.gradle
            sed -i "s/versionCode = [0-9]*/versionCode = $new_version_code/" android/app/build.gradle
        else
            sed -i "s/versionName = \".*\"/versionName = \"$new_version\"/" android/app/build.gradle
            local current_code=$(grep "versionCode" android/app/build.gradle | sed 's/.*versionCode = \([0-9]*\).*/\1/')
            local new_code=$((current_code + 1))
            sed -i "s/versionCode = [0-9]*/versionCode = $new_code/" android/app/build.gradle
        fi
    fi
    
    # Verify the update
    local updated_version=$(get_current_version)
    local expected_version="$new_version:$new_version_code"
    
    if [ "$updated_version" != "$expected_version" ]; then
        print_error "Version update failed. Expected: $expected_version, Got: $updated_version"
        exit 1
    fi
    
    print_status "Version updated successfully to $new_version ($new_version_code)"
}

# Function to update app ID and version
update_app_config() {
    local new_version=$1
    local new_version_code=$2
    
    print_step "Updating app configuration..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would update app configuration"
        return
    fi
    
    cd "$FLUTTER_APP_DIR"
    
    # Ensure app ID is correct for ContentCreator
    local current_app_id=$(grep "applicationId" android/app/build.gradle | sed 's/.*applicationId = "\(.*\)".*/\1/')
    if [ "$current_app_id" != "$APP_ID" ]; then
        print_verbose "Updating application ID from $current_app_id to $APP_ID"
        sed -i "s/applicationId = \"$current_app_id\"/applicationId = \"$APP_ID\"/" android/app/build.gradle
        sed -i "s/namespace = \"$current_app_id\"/namespace = \"$APP_ID\"/" android/app/build.gradle
    fi
    
    # Update version
    if [ $# -eq 2 ]; then
        # Update versionName and versionCode
        sed -i "s/versionName = \".*\"/versionName = \"$new_version\"/" android/app/build.gradle
        sed -i "s/versionCode = [0-9]*/versionCode = $new_version_code/" android/app/build.gradle
    else
        # Update only versionName and auto-increment versionCode
        sed -i "s/versionName = \".*\"/versionName = \"$new_version\"/" android/app/build.gradle
        local current_code=$(grep "versionCode" android/app/build.gradle | sed 's/.*versionCode = \([0-9]*\).*/\1/')
        local new_code=$((current_code + 1))
        sed -i "s/versionCode = [0-9]*/versionCode = $new_code/" android/app/build.gradle
    fi
    
    # Verify the update
    local updated_version=$(get_current_version)
    local expected_version="$new_version:$new_version_code"
    
    if [ "$updated_version" != "$expected_version" ]; then
        print_error "Version update failed. Expected: $expected_version, Got: $updated_version"
        exit 1
    fi
    
    print_status "App configuration updated successfully to $new_version ($new_version_code)"
}

# Function to run tests
run_tests() {
    print_verbose "DEBUG: SKIP_TESTS flag value: $SKIP_TESTS"
    
    if [ "$SKIP_TESTS" = true ]; then
        print_warning "Skipping tests as requested"
        return
    fi
    
    print_step "Running tests..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would run Flutter tests"
        return
    fi
    
    cd "$FLUTTER_APP_DIR"
    
    print_verbose "Running Flutter tests..."
    if flutter test; then
        print_status "All tests passed!"
    else
        print_error "Tests failed! Please fix the issues before continuing."
        if [ "$FORCE" != true ]; then
            exit 1
        else
            print_warning "Continuing due to --force flag"
        fi
    fi
}

# Function to build APK
build_apk() {
    if [ "$SKIP_BUILD" = true ]; then
        print_warning "Skipping build as requested"
        return
    fi
    
    print_step "Building APK..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would build APK"
        return
    fi
    
    cd "$FLUTTER_APP_DIR"
    
    # Get current version for APK naming
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    local apk_name="${APP_ID}_$version_code.apk"
    
    print_verbose "Building APK for version $version_name ($version_code)"
    
    # Clean and get dependencies
    print_verbose "Cleaning Flutter project..."
    flutter clean
    
    print_verbose "Getting Flutter dependencies..."
    flutter pub get
    
    # Check keystore configuration
    print_verbose "Checking keystore configuration..."
    if [ ! -f "android/key.properties" ]; then
        print_error "key.properties file not found!"
        exit 1
    fi
    
    if [ ! -f "android/app/release.keystore" ]; then
        print_error "release.keystore file not found!"
        exit 1
    fi
    
    # Build release APK
    print_verbose "Building release APK..."
    if ! flutter build apk --release --target-platform android-arm64; then
        print_error "APK build failed!"
        exit 1
    fi
    
    # Verify APK exists and is properly signed
    local apk_path="build/app/outputs/flutter-apk/app-release.apk"
    if [ ! -f "$apk_path" ]; then
        print_error "APK not found at $apk_path"
        exit 1
    fi
    
    # Check APK signature
    print_verbose "Verifying APK signature..."
    local signer_info=$(jarsigner -verify -verbose -certs "$apk_path" 2>/dev/null | grep "CN=" | head -1)
    if echo "$signer_info" | grep -q "Android Debug"; then
        print_error "APK is still debug signed! Check your keystore configuration."
        exit 1
    fi
    
    print_status "APK built and signed successfully: $signer_info"
    
    # Copy APK to F-Droid repository
    print_verbose "Copying APK to F-Droid repository..."
    cp "$apk_path" "$FDROID_DIR/repo/$apk_name"
    
    # Verify the APK was copied successfully
    if [ ! -f "$FDROID_DIR/repo/$apk_name" ]; then
        print_error "Failed to copy APK to F-Droid repository"
        exit 1
    fi
    
    print_status "APK built and deployed: $apk_name"
}

# Function to clean up old versions (keep only latest)
cleanup_old_versions() {
    print_step "Cleaning up old versions to keep only the latest..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would clean up old versions"
        return
    fi
    
    cd "$FDROID_DIR"
    
    # Get current version info
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    
    print_verbose "Current version: $version_name ($version_code)"
    
    # Clean up old APK files for this app (keep only the current one)
    print_verbose "Removing old APK files for $APP_NAME..."
    local removed_count=0
    for old_apk in repo/${APP_ID}_*.apk; do
        if [ -f "$old_apk" ]; then
            local apk_version_code=$(echo "$old_apk" | sed "s/.*${APP_ID}_\([0-9]*\)\.apk/\1/")
            if [ "$apk_version_code" != "$version_code" ]; then
                print_verbose "Removing old APK: $old_apk (version code: $apk_version_code)"
                rm -f "$old_apk"
                removed_count=$((removed_count + 1))
            fi
        fi
    done
    
    if [ $removed_count -gt 0 ]; then
        print_status "Removed $removed_count old APK files for $APP_NAME"
    else
        print_verbose "No old APK files found for $APP_NAME"
    fi
    
    # Clean up old cache files
    print_verbose "Clearing cache files..."
    rm -rf tmp/* 2>/dev/null || true
    rm -rf repo/diff/* 2>/dev/null || true
    print_verbose "Cache files cleared"
    
    # Force regenerate repository index to reflect only latest versions
    print_verbose "Regenerating repository index..."
    if ! fdroid update -c --create-metadata; then
        print_error "Failed to regenerate F-Droid repository index"
        exit 1
    fi
    
    print_status "Repository cleaned up - only latest versions remain"
}

# Function to update F-Droid repository
update_fdroid_repo() {
    print_step "Updating F-Droid repository..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would update F-Droid repository"
        return
    fi
    
    cd "$FDROID_DIR"
    
    # Get current version info
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    
    # Update metadata file
    print_verbose "Updating metadata file for $APP_ID..."
    
    # Create or update metadata file for this specific app
    print_verbose "Creating/updating metadata for $APP_NAME..."
    cat > metadata/${APP_ID}.yml << EOF
Categories:
  - $APP_CATEGORIES

License: MIT

WebSite: $APP_WEBSITE

SourceCode: $APP_SOURCE_CODE

IssueTracker: $APP_ISSUE_TRACKER

Donate: $APP_DONATE

Changelog: $APP_CHANGELOG

AutoName: $APP_NAME

Description: |
  $APP_DESCRIPTION
  
  Features:
  • Create and edit various types of content
  • AI-powered content generation
  • Multi-format export options
  • Cloud synchronization
  • Collaboration tools
  • Advanced editing capabilities
  
  Premium Features (available through in-app purchases):
  • Advanced AI features
  • Unlimited exports
  • Priority support
  • Premium templates
  
  Privacy-focused with secure content handling.

RepoType: git

Repo: $APP_REPO

Builds:
  - versionName: '$version_name'
    versionCode: $version_code
    commit: v$version_name
    subdir: $APP_SUBDIR
    output: build/app/outputs/flutter-apk/app-release.apk
    srclibs:
      - flutter@3.16.9

AutoUpdateMode: Version
UpdateCheckMode: Tags
CurrentVersion: '$version_name'
CurrentVersionCode: $version_code
EOF
    
    # Verify the metadata was created successfully
    if ! grep -q "versionName: '$version_name'" metadata/${APP_ID}.yml; then
        print_error "Failed to create metadata for version $version_name"
        exit 1
    fi
    
    if ! grep -q "versionCode: $version_code" metadata/${APP_ID}.yml; then
        print_error "Failed to create metadata for version code $version_code"
        exit 1
    fi
    
    print_verbose "Metadata created/updated successfully for $APP_NAME: $version_name ($version_code)"
    
    # Check if other apps exist and preserve them (KeyMatch is deprecated but kept for archival)
    print_verbose "Checking for other apps in repository..."
    local other_apps=()
    for metadata_file in metadata/*.yml; do
        if [ -f "$metadata_file" ] && [ "$(basename "$metadata_file")" != "${APP_ID}.yml" ]; then
            local other_app_name=$(grep "AutoName:" "$metadata_file" | sed 's/AutoName: //')
            local app_id=$(basename "$metadata_file" .yml)
            if [ "$app_id" = "com.keymatch.app" ]; then
                print_verbose "Found deprecated app: $other_app_name (will be preserved but not updated)"
            else
                other_apps+=("$other_app_name ($app_id)")
                print_verbose "Found other app: $other_app_name"
            fi
        fi
    done
    
    if [ ${#other_apps[@]} -gt 0 ]; then
        print_status "Preserving other apps: ${other_apps[*]}"
    fi
    
    # Clean up old versions first
    cleanup_old_versions
    
    # Show summary of apps in repository
    print_verbose "Current apps in repository:"
    for metadata_file in metadata/*.yml; do
        if [ -f "$metadata_file" ]; then
            local app_name=$(grep "AutoName:" "$metadata_file" | sed 's/AutoName: //')
            local app_version=$(grep "CurrentVersion:" "$metadata_file" | sed 's/CurrentVersion: //')
            local app_code=$(grep "CurrentVersionCode:" "$metadata_file" | sed 's/CurrentVersionCode: //')
            print_verbose "  - $app_name: v$app_version ($app_code)"
        fi
    done
}

# Function to commit and push changes
commit_and_push() {
    print_step "Committing and pushing changes..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would commit and push changes"
        return
    fi
    
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    
    # Commit F-Droid changes
    cd "$FDROID_DIR"
    git add .
    git commit -m "Update $APP_NAME to version $version_name ($version_code)

- Updated metadata with new version
- Updated repository index
- Ready for release"

    print_verbose "Pushing F-Droid changes to GitHub..."
    git push origin master
    
    # Create and push git tag
    cd "$CONTENT_CREATOR_DIR"
    print_verbose "Creating tag v$version_name..."
    git tag "v$version_name"
    print_verbose "Pushing tag to GitHub..."
    git push origin "v$version_name"
    
    # Commit version changes
    cd "$CONTENT_CREATOR_DIR"
    git add .
    git commit -m "Release version $version_name ($version_code)

- Updated version numbers in build.gradle
- Updated app ID to $APP_ID
- Ready for F-Droid distribution
- Version: $version_name (Code: $version_code)"

    print_verbose "Pushing version changes to GitHub..."
    git push origin main
    
    print_status "All changes committed and pushed successfully"
}

# Function to show keystore fingerprint
show_fingerprint() {
    print_step "Showing keystore fingerprint..."
    
    # Hardcoded values for easiest route
    local store_password='6LnBP33wv5vA+AcHOsb6VIjsw13rHvlqlvU/3avhvc8='
    local key_alias='klas-Modern-14-C7M'
    local store_file='/home/klas/Kod/content-creator/fdroid/keystore.p12'
    
    if [ ! -f "$store_file" ]; then
        print_error "Keystore file not found at: $store_file"
        return 1
    fi
    
    print_verbose "Reading fingerprint from keystore at: $store_file"
    local fingerprint=$(keytool -list -v -keystore "$store_file" -alias "$key_alias" -storepass "$store_password" -keypass "$store_password" 2>/dev/null | grep "SHA256:" | sed 's/.*SHA256: //')
    
    if [ -z "$fingerprint" ]; then
        print_error "Could not read fingerprint from keystore"
        print_verbose "Trying to debug keystore access..."
        keytool -list -v -keystore "$store_file" -alias "$key_alias" -storepass "$store_password" -keypass "$store_password" 2>&1 | head -10
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}🔐 Keystore Fingerprint:${NC}"
    echo "=========================================="
    echo -e "${GREEN}SHA256: $fingerprint${NC}"
    echo ""
    echo -e "${YELLOW}If you get a 'bad fingerprint' error in F-Droid:${NC}"
    echo "1. Open F-Droid app"
    echo "2. Go to Settings → Repositories"
    echo "3. Find your repository: https://klas96.github.io/fdroid/repo"
    echo "4. Tap on it and select 'Accept new fingerprint'"
    echo "5. The fingerprint above should match what F-Droid shows"
    echo ""
    
    return 0
}

# Function to show final summary
show_summary() {
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}🧪 DRY RUN COMPLETED${NC}"
    else
        echo -e "${GREEN}🎉 Release completed successfully!${NC}"
    fi
    echo "=========================================="
    echo -e "${CYAN}Release Summary:${NC}"
    echo "App: $APP_NAME"
    echo "App ID: $APP_ID"
    echo "Version: $version_name (Code: $version_code)"
    echo "Tag: v$version_name"
    echo "F-Droid Repository: https://klas96.github.io/fdroid/repo"
    echo "Direct APK: https://klas96.github.io/fdroid/repo/${APP_ID}_$version_code.apk"
    echo "Log file: $LOG_FILE"
    echo ""
    
    if [ "$DRY_RUN" != true ]; then
        echo -e "${YELLOW}Next Steps:${NC}"
        echo "1. Wait for GitHub Pages to update (usually 2-5 minutes)"
        echo "2. Test the new version from F-Droid repository"
        echo "3. Monitor for any issues"
        echo ""
        echo -e "${BLUE}Users can now install $APP_NAME $version_name from your F-Droid repository!${NC}"
    fi
}

# Main execution
main() {
    # Initialize log file
    echo "$APP_NAME Release Log - $(date)" > "$LOG_FILE"
    echo "=================================" >> "$LOG_FILE"
    
    # Validate environment
    validate_environment
    
    # Handle fingerprint-only mode
    if [ "$SHOW_FINGERPRINT" = true ]; then
        show_fingerprint
        exit 0
    fi
    
    # Check for repository conflicts
    check_repository_conflicts
    
    # Get version information
    local current_version_info=$(get_current_version)
    local current_version_name=$(echo "$current_version_info" | cut -d: -f1)
    local current_version_code=$(echo "$current_version_info" | cut -d: -f2)
    
    print_verbose "Current version: $current_version_name ($current_version_code)"
    
    # Filter out options to get version arguments
    local version_args=()
    for arg in "$@"; do
        case $arg in
            --dry-run|--skip-tests|--skip-build|--force|--verbose|--fingerprint|-h|--help)
                # Skip options
                ;;
            *)
                version_args+=("$arg")
                ;;
        esac
    done
    
    # Determine new version
    local new_version_name
    local new_version_code
    
    if [ ${#version_args[@]} -eq 2 ]; then
        new_version_name=${version_args[0]}
        new_version_code=${version_args[1]}
        print_status "Using provided version: $new_version_name (Code: $new_version_code)"
    elif [ ${#version_args[@]} -eq 1 ]; then
        new_version_name=${version_args[0]}
        new_version_code=$((current_version_code + 1))
        print_status "Using provided version name: $new_version_name (Auto-incremented code: $new_version_code)"
    else
        # Interactive mode - prompt for version
        print_step "Interactive version update..."
        read -p "Enter new version name (e.g., 1.0.4): " new_version_name
        read -p "Enter new version code (current: $current_version_code): " new_version_code
        if [ -z "$new_version_code" ]; then
            new_version_code=$((current_version_code + 1))
        fi
    fi
    
    # Update version (if not already done in interactive mode)
    if [ ${#version_args[@]} -gt 0 ]; then
        update_version "$new_version_name" "$new_version_code"
    fi
    
    # Debug output for test skipping
    print_verbose "DEBUG: About to run tests. SKIP_TESTS=$SKIP_TESTS, FORCE=$FORCE"
    
    # Run tests
    run_tests
    
    # Build APK
    build_apk
    
    # Update F-Droid repository
    update_fdroid_repo
    
    # Commit and push changes
    commit_and_push
    
    # Show summary
    show_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            print_verbose "DEBUG: Setting DRY_RUN=true"
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            print_verbose "DEBUG: Setting SKIP_TESTS=true"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            print_verbose "DEBUG: Setting SKIP_BUILD=true"
            shift
            ;;
        --force)
            FORCE=true
            print_verbose "DEBUG: Setting FORCE=true"
            shift
            ;;
        --verbose)
            VERBOSE=true
            print_verbose "DEBUG: Setting VERBOSE=true"
            shift
            ;;
        --fingerprint)
            SHOW_FINGERPRINT=true
            print_verbose "DEBUG: Setting SHOW_FINGERPRINT=true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [VERSION] [VERSION_CODE]"
            echo ""
            echo "Options:"
            echo "  --dry-run     Run without making actual changes"
            echo "  --skip-tests  Skip running tests"
            echo "  --skip-build  Skip building APK (use existing)"
            echo "  --force       Force release even if issues detected"
            echo "  --verbose     Enable verbose output"
            echo "  --fingerprint Show keystore fingerprint for F-Droid"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "Examples:"
echo "  $0                    # Interactive mode (prompts for version)"
echo "  $0 1.0.1             # Version 1.0.1 (auto-increments version code)"
echo "  $0 1.0.1 101         # Version 1.0.1 with specific version code 101"
echo "  $0 --skip-tests 1.0.2 # Skip tests and use version 1.0.2"
echo "  $0 --dry-run 1.0.3   # Test run with version 1.0.3"
echo "  $0 --fingerprint     # Show keystore fingerprint"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

echo -e "${PURPLE}🎯 $APP_NAME F-Droid Release Script${NC}"
echo "=================================================="
echo -e "${CYAN}This script will:${NC}"
echo "1. 📝 Update version numbers"
echo "2. 🔍 Check repository version"
echo "3. 🧪 Run tests (unless skipped)"
echo "4. 🏗️  Build and deploy to F-Droid"
echo "5. 🏷️  Create Git tag"
echo "6. 📤 Push changes to GitHub"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}⚠️  DRY RUN MODE - No actual changes will be made${NC}"
    echo ""
fi

# Run main function with all arguments
main "$@" 