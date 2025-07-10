#!/bin/bash

# Always run from the Flutter project root
cd "$(dirname "$0")/.."

# Build APK and Upload to Google Drive Script
# This script builds a Flutter APK and uploads it to Google Drive

set -e  # Exit on any error

# Configuration
APP_NAME="content-creator"
BUILD_TYPE="release"
OUTPUT_DIR="build/app/outputs/flutter-apk"
GDRIVE_FOLDER_PATH="AI-Project/content-creator/releases"  # Google Drive folder path
GDRIVE_CREDENTIALS_FILE="~/Downloads/gdrive-credentials.json"  # Update path as needed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get version from pubspec.yaml
get_version() {
    local version=$(grep 'version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
    echo "$version"
}

# Function to get APK path
get_apk_path() {
    local apk_file="app-release.apk"
    local apk_path="${OUTPUT_DIR}/${apk_file}"
    echo "$apk_path"
}

# Function to rename APK with version
rename_apk() {
    local apk_path="$1"
    local version=$(get_version)
    local new_name="${APP_NAME}-${BUILD_TYPE}-${version}.apk"
    local new_path="${OUTPUT_DIR}/${new_name}"
    
    if [ "$apk_path" != "$new_path" ]; then
        mv "$apk_path" "$new_path"
        echo "$new_path"
    else
        echo "$apk_path"
    fi
}

# Function to upload to Google Drive using rsync
upload_to_gdrive_rsync() {
    local apk_path="$1"
    
    # Find Google Drive mount point
    local gdrive_mount=""
    local possible_mounts=(
        "$HOME/Google Drive"
        "$HOME/google-drive"
        "/mnt/google-drive"
        "/media/$USER/google-drive"
    )
    
    for mount in "${possible_mounts[@]}"; do
        if [ -d "$mount" ]; then
            gdrive_mount="$mount"
            break
        fi
    done
    
    if [ -z "$gdrive_mount" ]; then
        print_warning "Google Drive not found at common mount points:"
        for mount in "${possible_mounts[@]}"; do
            echo "  - $mount"
        done
        return 1
    fi
    
    local target_dir="${gdrive_mount}/${GDRIVE_FOLDER_PATH}"
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    print_status "Uploading to Google Drive using rsync..."
    print_status "Source: $apk_path"
    print_status "Target: $target_dir"
    
    rsync -av --progress "$apk_path" "$target_dir/"
    
    if [ $? -eq 0 ]; then
        print_success "APK uploaded to Google Drive successfully!"
        print_status "Location: $target_dir/$(basename "$apk_path")"
        return 0
    else
        print_error "Failed to upload to Google Drive"
        return 1
    fi
}

# Function to upload to Google Drive using gdrive CLI
upload_to_gdrive_cli() {
    local apk_path="$1"
    
    if ! command_exists gdrive; then
        print_warning "gdrive CLI not found. Please install it first:"
        echo "  go install github.com/glotlabs/gdrive@latest"
        echo "  or download from: https://github.com/glotlabs/gdrive/releases"
        return 1
    fi
    
    print_status "Uploading to Google Drive using gdrive CLI..."
    
    # Upload to the specific folder path
    gdrive upload --path "$GDRIVE_FOLDER_PATH" "$apk_path"
    
    if [ $? -eq 0 ]; then
        print_success "APK uploaded to Google Drive successfully!"
        return 0
    else
        print_error "Failed to upload to Google Drive"
        return 1
    fi
}

# Function to create backup
create_backup() {
    local apk_path="$1"
    local backup_dir="backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="$(basename "$apk_path" .apk)_${timestamp}.apk"
    local backup_path="${backup_dir}/${backup_name}"
    
    mkdir -p "$backup_dir"
    cp "$apk_path" "$backup_path"
    print_success "Backup created: $backup_path"
}

# Function to upload to Google Drive using rclone
upload_to_gdrive_rclone() {
    local apk_path="$1"
    local remote_path="gdrive:AI-Project/content-creator/releases/"
    if ! command_exists rclone; then
        print_warning "rclone not found. Please install it: sudo apt install rclone"
        return 1
    fi
    print_status "Uploading to Google Drive using rclone..."
    rclone copy "$apk_path" "$remote_path" --progress
    if [ $? -eq 0 ]; then
        print_success "APK uploaded to Google Drive successfully via rclone!"
        print_status "Location: $remote_path$(basename "$apk_path")"
        return 0
    else
        print_error "Failed to upload to Google Drive via rclone"
        return 1
    fi
}

# Main function
main() {
    print_status "Starting APK build and upload process..."
    echo "=================================="
    
    # Get version
    local version=$(get_version)
    print_status "Building version: $version"
    
    # Clean previous builds
    print_status "Cleaning previous builds..."
    flutter clean
    
    # Build APK
    print_status "Building release APK..."
    flutter build apk --release
    
    if [ $? -eq 0 ]; then
        print_success "APK built successfully!"
    else
        print_error "APK build failed!"
        exit 1
    fi
    
    print_success "APK Build Complete!"
    echo "=================================="
    echo "App Name: $APP_NAME"
    echo "Version: $version"
    echo "Build Type: $BUILD_TYPE"
    
    # Get APK path and rename if needed
    local apk_path
    apk_path=$(get_apk_path)
    local version=$(get_version)
    local new_name="${APP_NAME}-${BUILD_TYPE}-${version}.apk"
    local new_path="${OUTPUT_DIR}/${new_name}"
    
    if [ "$apk_path" != "$new_path" ]; then
        mv "$apk_path" "$new_path"
    fi
    apk_path="$new_path"
    print_status "Renaming APK to include version..."
    
    echo "APK Path: $apk_path"
    
    # Check APK size
    local apk_size=$(du -h "$apk_path" | cut -f1)
    echo "APK Size: $apk_size"
    echo "=================================="
    
    # Create backup
    print_status "Creating backup..."
    create_backup "$apk_path"
    
    # Try to upload to Google Drive
    print_status "Attempting to upload to Google Drive..."
    # Try rclone method first
    if upload_to_gdrive_rclone "$apk_path"; then
        print_success "Upload completed successfully!"
    elif upload_to_gdrive_rsync "$apk_path"; then
        print_success "Upload completed successfully!"
    elif upload_to_gdrive_cli "$apk_path"; then
        print_success "Upload completed successfully!"
    else
        print_warning "Could not upload to Google Drive automatically."
        print_status "APK is available at: $apk_path"
        print_status "Please upload manually to Google Drive."
    fi
    
    print_success "Process completed!"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build and upload APK to Google Drive"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo ""
    echo "Environment variables:"
    echo "  GDRIVE_FOLDER_PATH   Google Drive folder path (default: AI-Project/content-creator/releases)"
    echo "  GDRIVE_CREDENTIALS_FILE  Path to Google Drive credentials"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "Version: $(get_version)"
        exit 0
        ;;
    "")
        main "$@"
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 