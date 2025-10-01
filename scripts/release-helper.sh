#!/bin/bash

# --- Ensure script is run with Bash ---
if [ -z "$BASH_VERSION" ]; then
  echo "❌ This script must be run with bash, not sh."
  echo "   Try: bash $0 ... or make it executable and run ./$0 ..."
  exit 1
fi

# KeyMatch Release Helper Script
# This script provides utilities for managing releases and troubleshooting issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(pwd)"
KEY_MATCH_DIR="$PROJECT_ROOT/key-match"
DATING_APP_DIR="$KEY_MATCH_DIR/dating_app"
FDROID_DIR="$PROJECT_ROOT/fdroid"

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status          Show current release status"
    echo "  rollback        Rollback to previous version"
    echo "  verify          Verify current setup"
    echo "  clean           Clean build artifacts"
    echo "  logs            Show recent release logs"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Check current status"
    echo "  $0 rollback 1.0.5           # Rollback to version 1.0.5"
    echo "  $0 verify                    # Verify environment"
    echo "  $0 clean                     # Clean build files"
}

# Function to get current version
get_current_version() {
    cd "$DATING_APP_DIR"
    local version_name=$(grep "versionName" android/app/build.gradle | sed 's/.*versionName = "\(.*\)".*/\1/')
    local version_code=$(grep "versionCode" android/app/build.gradle | sed 's/.*versionCode = \([0-9]*\).*/\1/')
    echo "$version_name:$version_code"
}

# Function to check status
check_status() {
    print_step "Checking release status..."
    
    # Check current version
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d: -f1)
    local version_code=$(echo "$version_info" | cut -d: -f2)
    
    echo "Current version: $version_name (Code: $version_code)"
    
    # Check if APK exists in F-Droid repo
    local apk_path="$FDROID_DIR/repo/com.keymatch.app_$version_code.apk"
    if [ -f "$apk_path" ]; then
        print_status "APK exists in F-Droid repository"
        local apk_size=$(du -h "$apk_path" | cut -f1)
        echo "APK size: $apk_size"
    else
        print_warning "APK not found in F-Droid repository"
    fi
    
    # Check git status
    cd "$KEY_MATCH_DIR"
    if git diff-index --quiet HEAD --; then
        print_status "No uncommitted changes in key-match"
    else
        print_warning "Uncommitted changes in key-match"
        git status --porcelain
    fi
    
    cd "$FDROID_DIR"
    if git diff-index --quiet HEAD --; then
        print_status "No uncommitted changes in F-Droid repo"
    else
        print_warning "Uncommitted changes in F-Droid repo"
        git status --porcelain
    fi
    
    # Check recent tags
    cd "$KEY_MATCH_DIR"
    echo ""
    echo "Recent tags:"
    git tag --sort=-version:refname | head -5
    
    # Check F-Droid metadata
    cd "$FDROID_DIR"
    local metadata_version=$(grep "CurrentVersion:" metadata/com.keymatch.app.yml | sed 's/CurrentVersion: //')
    local metadata_code=$(grep "CurrentVersionCode:" metadata/com.keymatch.app.yml | sed 's/CurrentVersionCode: //')
    echo ""
    echo "F-Droid metadata version: $metadata_version (Code: $metadata_code)"
    
    if [ "$metadata_version" = "$version_name" ] && [ "$metadata_code" = "$version_code" ]; then
        print_status "F-Droid metadata matches current version"
    else
        print_warning "F-Droid metadata version mismatch"
    fi
}

# Function to rollback
rollback() {
    local target_version=$1
    
    if [ -z "$target_version" ]; then
        print_error "Please specify a version to rollback to"
        echo "Usage: $0 rollback <version>"
        exit 1
    fi
    
    print_step "Rolling back to version $target_version..."
    
    # Check if version exists
    cd "$KEY_MATCH_DIR"
    if ! git tag | grep -q "v$target_version"; then
        print_error "Tag v$target_version not found"
        echo "Available tags:"
        git tag --sort=-version:refname | head -10
        exit 1
    fi
    
    # Confirm rollback
    read -p "Are you sure you want to rollback to version $target_version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Rollback cancelled"
        exit 1
    fi
    
    # Rollback key-match repository
    print_info "Rolling back key-match repository..."
    cd "$KEY_MATCH_DIR"
    git checkout "v$target_version"
    
    # Rollback F-Droid repository
    print_info "Rolling back F-Droid repository..."
    cd "$FDROID_DIR"
    
    # Find the commit that updated to the target version
    local rollback_commit=$(git log --oneline | grep "$target_version" | head -1 | cut -d' ' -f1)
    if [ -n "$rollback_commit" ]; then
        git checkout "$rollback_commit"
    else
        print_warning "Could not find F-Droid commit for version $target_version"
        print_info "You may need to manually update the F-Droid metadata"
    fi
    
    print_status "Rollback completed"
    echo "Current version: $(get_current_version)"
}

# Function to verify setup
verify_setup() {
    print_step "Verifying release setup..."
    
    # Check directories
    local missing_dirs=()
    if [ ! -d "$KEY_MATCH_DIR" ]; then
        missing_dirs+=("key-match")
    fi
    if [ ! -d "$DATING_APP_DIR" ]; then
        missing_dirs+=("dating_app")
    fi
    if [ ! -d "$FDROID_DIR" ]; then
        missing_dirs+=("fdroid")
    fi
    
    if [ ${#missing_dirs[@]} -ne 0 ]; then
        print_error "Missing directories: ${missing_dirs[*]}"
        exit 1
    fi
    
    # Check required files
    local missing_files=()
    if [ ! -f "$DATING_APP_DIR/android/key.properties" ]; then
        missing_files+=("android/key.properties")
    fi
    if [ ! -f "$DATING_APP_DIR/android/release.keystore" ]; then
        missing_files+=("android/release.keystore")
    fi
    if [ ! -f "$FDROID_DIR/metadata/com.keymatch.app.yml" ]; then
        missing_files+=("F-Droid metadata")
    fi
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Missing required files: ${missing_files[*]}"
        exit 1
    fi
    
    # Check commands
    local missing_commands=()
    if ! command -v flutter &> /dev/null; then
        missing_commands+=("flutter")
    fi
    if ! command -v git &> /dev/null; then
        missing_commands+=("git")
    fi
    if ! command -v fdroid &> /dev/null; then
        missing_commands+=("fdroid")
    fi
    if ! command -v jarsigner &> /dev/null; then
        missing_commands+=("jarsigner")
    fi
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_error "Missing commands: ${missing_commands[*]}"
        exit 1
    fi
    
    # Check Flutter setup
    cd "$DATING_APP_DIR"
    if ! flutter doctor --android-licenses &> /dev/null; then
        print_warning "Android licenses not accepted. Run: flutter doctor --android-licenses"
    fi
    
    print_status "Setup verification passed"
}

# Function to clean build artifacts
clean_builds() {
    print_step "Cleaning build artifacts..."
    
    # Clean Flutter build
    cd "$DATING_APP_DIR"
    print_info "Cleaning Flutter build..."
    flutter clean
    
    # Clean F-Droid build cache
    cd "$FDROID_DIR"
    print_info "Cleaning F-Droid cache..."
    rm -rf tmp/
    rm -rf build/
    rm -rf logs/
    
    print_status "Build artifacts cleaned"
}

# Function to show logs
show_logs() {
    print_step "Recent release logs..."
    
    local log_files=($(ls -t release-*.log 2>/dev/null | head -5))
    
    if [ ${#log_files[@]} -eq 0 ]; then
        print_info "No release logs found"
        return
    fi
    
    for log_file in "${log_files[@]}"; do
        echo ""
        echo "=== $log_file ==="
        tail -20 "$log_file"
    done
}

# Main execution
case "${1:-help}" in
    status)
        check_status
        ;;
    rollback)
        rollback "$2"
        ;;
    verify)
        verify_setup
        ;;
    clean)
        clean_builds
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 