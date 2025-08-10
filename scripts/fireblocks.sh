#!/bin/bash

set -e

# Configuration
AGAVE_REPO="carteraMesh/agave"
TOKEN_REPO="CarteraMesh/token-2022"
INSTALL_DIR="$HOME/.local/bin"
AGAVE_BINARY="solana"
TOKEN_BINARY="spl-token"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v tar &> /dev/null; then
        missing_deps+=("tar")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them and try again."
        log_info "On Ubuntu/Debian: sudo apt-get install curl jq tar"
        log_info "On macOS: brew install curl jq"
        exit 1
    fi
}

# Detect platform
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        linux)
            case "$arch" in
                x86_64)
                    echo "linux-x86_64"
                    ;;
                *)
                    log_error "Unsupported architecture: $arch"
                    exit 1
                    ;;
            esac
            ;;
        darwin)
            case "$arch" in
                arm64)
                    echo "macos-arm64"
                    ;;
                *)
                    log_error "Unsupported architecture: $arch"
                    exit 1
                    ;;
            esac
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
}

# Get latest release info
get_latest_release() {
    local repo="$1"
    log_info "Fetching latest release information for $repo..."
    
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local release_info
    
    if ! release_info=$(curl -s "$api_url"); then
        log_error "Failed to fetch release information from GitHub API for $repo"
        exit 1
    fi
    
    local tag_name=$(echo "$release_info" | jq -r '.tag_name')
    
    if [ "$tag_name" = "null" ] || [ -z "$tag_name" ]; then
        log_error "No releases found for repository $repo"
        exit 1
    fi
    
    echo "$tag_name"
}

# Download and install
install_binary() {
    local platform="$1"
    local repo="$2"
    local version="$3"
    local binary_name="$4"
    local filename_prefix="$5"
    
    # Remove 'v' prefix from version for filename
    local version_clean="${version#v}"
    local filename="${filename_prefix}-${version_clean}-${platform}.tar.gz"
    local download_url="https://github.com/$repo/releases/download/$version/$filename"
    
    log_info "Downloading $filename..."
    log_info "URL: $download_url"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    local temp_file="$temp_dir/$filename"
    
    # Download the file
    if ! curl -s -L -o "$temp_file" "$download_url"; then
        log_error "Failed to download $filename"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Extract and install
    log_info "Installing $binary_name to $INSTALL_DIR..."
    
    if ! tar -xzf "$temp_file" -C "$temp_dir"; then
        log_error "Failed to extract $filename"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Move binary to install directory
    if ! mv "$temp_dir/$binary_name" "$INSTALL_DIR/$binary_name"; then
        log_error "Failed to install $binary_name to $INSTALL_DIR"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Make executable
    chmod +x "$INSTALL_DIR/$binary_name"
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_success "Successfully installed $binary_name!"
}

# Check PATH
check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "$INSTALL_DIR is not in your PATH"
        log_info "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        log_info "export PATH=\"\$PATH:$INSTALL_DIR\""
        log_info ""
        log_info "Or run: echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.bashrc"
        log_info "Then restart your shell or run: source ~/.bashrc"
    fi
}

# Verify installation
verify_installation() {
    local binary_name="$1"
    local integration_check="$2"
    
    log_info "Verifying $binary_name installation..."
    
    if [ -x "$INSTALL_DIR/$binary_name" ]; then
        local version_output=$("$INSTALL_DIR/$binary_name" --version 2>/dev/null || echo "Failed to get version")
        log_success "$binary_name installation verified!"
        log_info "Version: $version_output"
        
        if [ -n "$integration_check" ] && [[ "$version_output" == *"$integration_check"* ]]; then
            log_success "$integration_check integration confirmed!"
        elif [ -n "$integration_check" ]; then
            log_warning "$integration_check integration not detected in version string"
        fi
    else
        log_error "$binary_name installation verification failed - binary not found or not executable"
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install the latest Solana CLI and SPL Token CLI with Fireblocks integration"
    echo "  - Solana CLI from: $AGAVE_REPO"
    echo "  - SPL Token CLI from: $TOKEN_REPO"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Force reinstallation even if already installed"
    echo ""
    echo "The binaries will be installed to: $INSTALL_DIR"
}

# Main function
main() {
    local force_install=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                force_install=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Installing Solana CLI and SPL Token CLI with Fireblocks integration..."
    log_info "Agave repository: https://github.com/$AGAVE_REPO"
    log_info "Token repository: https://github.com/$TOKEN_REPO"
    log_info "Install directory: $INSTALL_DIR"
    
    # Check if already installed
    if [ -x "$INSTALL_DIR/$AGAVE_BINARY" ] && [ -x "$INSTALL_DIR/$TOKEN_BINARY" ] && [ "$force_install" = false ]; then
        local solana_version=$("$INSTALL_DIR/$AGAVE_BINARY" --version 2>/dev/null || echo "unknown")
        local token_version=$("$INSTALL_DIR/$TOKEN_BINARY" --version 2>/dev/null || echo "unknown")
        log_warning "Both binaries are already installed:"
        log_info "Solana CLI: $solana_version"
        log_info "SPL Token CLI: $token_version"
        log_info "Use --force to reinstall"
        exit 0
    fi
    
    # Run installation steps
    check_dependencies
    local platform=$(detect_platform)
    
    # Get latest versions
    local agave_version=$(get_latest_release "$AGAVE_REPO")
    local token_version=$(get_latest_release "$TOKEN_REPO")
    
    log_info "Platform: $platform"
    log_info "Agave latest version: $agave_version"
    log_info "Token latest version: $token_version"
    
    # Install both binaries
    install_binary "$platform" "$AGAVE_REPO" "$agave_version" "$AGAVE_BINARY" "solana-cli"
    install_binary "$platform" "$TOKEN_REPO" "$token_version" "$TOKEN_BINARY" "spl-token"
    
    # Verify installations
    verify_installation "$AGAVE_BINARY" "fireblocks"
    verify_installation "$TOKEN_BINARY" ""
    
    check_path
    
    log_success "Installation complete!"
    log_info "Run 'solana --version' and 'spl-token --version' to verify the installations"
}

# Run main function with all arguments
main "$@"
