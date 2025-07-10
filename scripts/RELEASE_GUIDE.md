# KeyMatch Release Guide

This guide explains how to use the improved release scripts for KeyMatch F-Droid distribution.

## Overview

The release process has been significantly improved with better error handling, validation, and flexibility. Two main scripts are provided:

1. **`release-to-fdroid.sh`** - Main release script with enhanced features
2. **`release-helper.sh`** - Helper script for troubleshooting and management

## Quick Start

### Basic Release (Interactive)
```bash
./release-to-fdroid.sh
```

### Release with Specific Version
```bash
./release-to-fdroid.sh 1.2.0 111
```

### Test Run (Dry Run)
```bash
./release-to-fdroid.sh --dry-run 1.2.0
```

## Main Release Script Features

### Command Line Options

- `--dry-run` - Run without making actual changes
- `--skip-tests` - Skip running Flutter tests
- `--skip-build` - Skip building APK (use existing)
- `--force` - Force release even if issues detected
- `--verbose` - Enable verbose output
- `-h, --help` - Show help message

### Examples

```bash
# Interactive release
./release-to-fdroid.sh

# Specific version with auto-incremented code
./release-to-fdroid.sh 1.2.0

# Specific version and code
./release-to-fdroid.sh 1.2.0 111

# Test run without making changes
./release-to-fdroid.sh --dry-run 1.2.0

# Skip tests (useful for quick releases)
./release-to-fdroid.sh --skip-tests 1.2.0

# Force release despite warnings
./release-to-fdroid.sh --force 1.2.0

# Verbose output for debugging
./release-to-fdroid.sh --verbose 1.2.0
```

## Helper Script Features

### Check Current Status
```bash
./release-helper.sh status
```

### Verify Setup
```bash
./release-helper.sh verify
```

### Clean Build Artifacts
```bash
./release-helper.sh clean
```

### View Recent Logs
```bash
./release-helper.sh logs
```

### Rollback to Previous Version
```bash
./release-helper.sh rollback 1.0.5
```

## What the Scripts Do

### Main Release Script (`release-to-fdroid.sh`)

1. **Environment Validation**
   - Checks for required directories and files
   - Verifies all required commands are available
   - Validates Flutter setup and Android licenses
   - Checks for uncommitted changes

2. **Version Management**
   - Updates version numbers in `pubspec.yaml` and `build.gradle`
   - Supports interactive or command-line version specification
   - Verifies version updates were successful

3. **Testing**
   - Runs Flutter tests (can be skipped with `--skip-tests`)
   - Provides detailed error reporting

4. **APK Building**
   - Cleans and rebuilds the Flutter project
   - Verifies keystore configuration
   - Builds release APK with proper signing
   - Validates APK signature
   - Dynamically names APK based on version code

5. **F-Droid Integration**
   - Updates F-Droid metadata with new version
   - Updates repository index
   - Commits and pushes changes

6. **Git Management**
   - Creates and pushes git tags
   - Commits version changes
   - Pushes to appropriate branches

7. **Logging and Reporting**
   - Comprehensive logging to timestamped files
   - Detailed progress reporting
   - Final summary with links and next steps

### Helper Script (`release-helper.sh`)

1. **Status Checking**
   - Current version information
   - APK existence and size
   - Git repository status
   - F-Droid metadata verification

2. **Setup Verification**
   - Required directories and files
   - Command availability
   - Flutter configuration

3. **Maintenance**
   - Clean build artifacts
   - View release logs
   - Rollback functionality

4. **Troubleshooting**
   - Detailed error messages
   - Suggested fixes
   - Log analysis

## Improvements Over Previous Version

### 1. **Dynamic APK Naming**
- **Before**: Hardcoded APK name (`com.keymatch.app_108.apk`)
- **After**: Dynamic naming based on version code (`com.keymatch.app_110.apk`)

### 2. **Comprehensive Validation**
- **Before**: Basic directory checks
- **After**: Full environment validation including commands, files, and git status

### 3. **Better Error Handling**
- **Before**: Script stops on first error
- **After**: Detailed error reporting with suggestions and recovery options

### 4. **Flexibility Options**
- **Before**: Single workflow
- **After**: Multiple options for different scenarios (dry-run, skip-tests, force, etc.)

### 5. **Logging and Debugging**
- **Before**: Basic console output
- **After**: Comprehensive logging with timestamps and verbose mode

### 6. **Rollback Support**
- **Before**: Manual rollback process
- **After**: Automated rollback with helper script

### 7. **Status Monitoring**
- **Before**: No status checking
- **After**: Comprehensive status reporting and verification

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```bash
   # Check what's missing
   ./release-helper.sh verify
   
   # Install missing tools
   sudo apt install openjdk-11-jdk
   pip install fdroidserver
   ```

2. **Android Licenses Not Accepted**
   ```bash
   cd key-match/dating_app
   flutter doctor --android-licenses
   ```

3. **Keystore Issues**
   ```bash
   # Check keystore files exist
   ls -la key-match/dating_app/android/
   
   # Verify key.properties configuration
   cat key-match/dating_app/android/key.properties
   ```

4. **Build Failures**
   ```bash
   # Clean and retry
   ./release-helper.sh clean
   ./release-to-fdroid.sh --verbose 1.2.0
   ```

5. **Version Conflicts**
   ```bash
   # Check current status
   ./release-helper.sh status
   
   # Rollback if needed
   ./release-helper.sh rollback 1.0.5
   ```

### Debug Mode

For detailed debugging, use verbose mode:
```bash
./release-to-fdroid.sh --verbose --dry-run 1.2.0
```

This will show all internal operations without making changes.

## Best Practices

1. **Always Test First**
   ```bash
   ./release-to-fdroid.sh --dry-run 1.2.0
   ```

2. **Check Status Before Release**
   ```bash
   ./release-helper.sh status
   ```

3. **Verify Setup Regularly**
   ```bash
   ./release-helper.sh verify
   ```

4. **Keep Logs for Debugging**
   - Log files are automatically created with timestamps
   - Use `./release-helper.sh logs` to view recent logs

5. **Use Force Sparingly**
   - Only use `--force` when you understand the risks
   - Always check what's being skipped

## File Structure

```
key-match-project/
├── release-to-fdroid.sh          # Main release script
├── release-helper.sh             # Helper script
├── RELEASE_GUIDE.md             # This guide
├── release-*.log                 # Release logs (auto-generated)
├── key-match/                    # Main project
│   └── dating_app/              # Flutter app
└── fdroid/                      # F-Droid repository
    ├── metadata/
    │   └── com.keymatch.app.yml # App metadata
    └── repo/                    # APK storage
```

## Support

If you encounter issues:

1. Check the logs: `./release-helper.sh logs`
2. Verify setup: `./release-helper.sh verify`
3. Check status: `./release-helper.sh status`
4. Try dry-run: `./release-to-fdroid.sh --dry-run --verbose`

The improved scripts provide much better error messages and suggestions for common issues. 