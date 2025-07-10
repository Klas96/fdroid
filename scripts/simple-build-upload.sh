#!/bin/bash

# Always run from the Flutter project root
cd "$(dirname "$0")/.."

set -e  # Exit on any error

# Configuration
APP_NAME="content-creator"
BUILD_TYPE="release"
OUTPUT_DIR="build/app/outputs/flutter-apk"

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
    
    # Get APK path - use the default Flutter output
    local apk_path="${OUTPUT_DIR}/app-release.apk"
    
    # Check if APK exists
    if [ ! -f "$apk_path" ]; then
        print_error "APK not found at: $apk_path"
        exit 1
    fi
    
    echo "APK Path: $apk_path"
    
    # Check APK size
    local apk_size=$(du -h "$apk_path" | cut -f1)
    echo "APK Size: $apk_size"
    echo "=================================="
    
    # Try to upload to Google Drive
    print_status "Attempting to upload to Google Drive..."
    
    if upload_to_gdrive_rclone "$apk_path"; then
        print_success "Upload completed successfully!"
    else
        print_warning "Could not upload to Google Drive automatically."
        print_status "APK is available at: $apk_path"
        print_status "Please upload manually to Google Drive."
    fi
    
    print_success "Process completed!"
}

main "$@" 