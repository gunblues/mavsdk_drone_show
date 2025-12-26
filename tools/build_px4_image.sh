#!/bin/bash
# =============================================================================
# Script Name: build_px4_image.sh
# Description: Build PX4 Docker image for drone show SITL simulation
# Author: MARLIN Team
# Date: December 2025
# =============================================================================
#
# This script builds a Docker image with PX4 SITL installed from scratch.
#
# Usage:
#   bash tools/build_px4_image.sh [OPTIONS]
#
# Options:
#   --output IMAGE        Output image name (default: drone-template-px4:latest)
#   --branch BRANCH       PX4 branch to use (default: v1.14.3)
#   --ssh-key "KEY"       SSH deploy key content for private MARLIN repo
#   --marlin-branch NAME  MARLIN branch to clone (default: main)
#   --help                Show this help message
#
# Environment Variables:
#   MARLIN_SSH_KEY        SSH deploy key content (alternative to --ssh-key)
#
# Examples:
#   # Using environment variable
#   export MARLIN_SSH_KEY="$(cat ~/.ssh/marlin_deploy_key)"
#   bash tools/build_px4_image.sh
#
#   # Using command line argument
#   bash tools/build_px4_image.sh --ssh-key "$(cat ~/.ssh/marlin_deploy_key)"
#
# =============================================================================

set -euo pipefail

SCRIPT_VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Default values (with environment variable override support)
BASE_IMAGE="ubuntu:22.04"
OUTPUT_IMAGE="drone-template-px4:latest"
PX4_BRANCH="v1.14.3"
SSH_KEY_CONTENT="${MARLIN_SSH_KEY:-}"
MARLIN_REPO_URL="${MARLIN_REPO_URL:-git@github.com:valteq/marlin.git}"
MARLIN_BRANCH="${MARLIN_BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build PX4 Docker image for drone show SITL simulation.

Options:
  --output IMAGE        Output image name (default: drone-template-px4:latest)
  --branch BRANCH       PX4 branch to use (default: v1.14.3)
  --ssh-key "KEY"       SSH deploy key content for private MARLIN repo
  --marlin-branch NAME  MARLIN branch to clone (default: main)
  --help                Show this help message

Environment Variables:
  MARLIN_SSH_KEY        SSH deploy key content (alternative to --ssh-key)
  MARLIN_REPO_URL       Git repository URL (default: git@github.com:valteq/marlin.git)
  MARLIN_BRANCH         Git branch to clone (default: main)

Examples:
  export MARLIN_SSH_KEY="\$(cat ~/.ssh/marlin_deploy_key)"
  $(basename "$0")

  $(basename "$0") --ssh-key "\$(cat ~/.ssh/marlin_deploy_key)"
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_IMAGE="$2"
            shift 2
            ;;
        --branch)
            PX4_BRANCH="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_CONTENT="$2"
            shift 2
            ;;
        --marlin-branch)
            MARLIN_BRANCH="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate SSH key
if [[ -z "$SSH_KEY_CONTENT" ]]; then
    log_error "SSH deploy key is required."
    log_error "Set MARLIN_SSH_KEY environment variable or use --ssh-key option"
    exit 1
fi

echo "=============================================="
echo " PX4 Docker Image Builder v${SCRIPT_VERSION}"
echo "=============================================="
echo ""
echo "Configuration:"
echo "  Base Image: $BASE_IMAGE"
echo "  Output Image: $OUTPUT_IMAGE"
echo "  PX4 Branch: $PX4_BRANCH"
echo "  MARLIN Repo: $MARLIN_REPO_URL"
echo "  MARLIN Branch: $MARLIN_BRANCH"
echo "  SSH Key: [PROVIDED]"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Pull base image
log_info "Pulling base image: $BASE_IMAGE"
docker pull "$BASE_IMAGE"

# Create temporary container name
TEMP_CONTAINER="px4-build-$(date +%s)"

log_info "Creating temporary container: $TEMP_CONTAINER"
docker run --name "$TEMP_CONTAINER" -d "$BASE_IMAGE" tail -f /dev/null

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary container..."
    docker rm -f "$TEMP_CONTAINER" 2>/dev/null || true
}
trap cleanup EXIT

# Setup SSH key in container
log_info "Setting up SSH deploy key in container..."
docker exec "$TEMP_CONTAINER" mkdir -p /root/.ssh
docker exec "$TEMP_CONTAINER" bash -c "cat > /root/.ssh/deploy_key << 'SSHKEYEOF'
${SSH_KEY_CONTENT}
SSHKEYEOF"
docker exec "$TEMP_CONTAINER" chmod 600 /root/.ssh/deploy_key
docker exec "$TEMP_CONTAINER" bash -c 'cat > /root/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/deploy_key
    StrictHostKeyChecking no
EOF'
docker exec "$TEMP_CONTAINER" chmod 600 /root/.ssh/config

log_info "Installing PX4 and dependencies inside container... (this will take a while)"

# Install PX4 inside the container
docker exec "$TEMP_CONTAINER" bash -c "
    set -e

    export DEBIAN_FRONTEND=noninteractive

    echo '=== Updating package lists ==='
    apt-get update

    echo '=== Installing base dependencies ==='
    apt-get install -y \\
        git \\
        wget \\
        curl \\
        sudo \\
        lsb-release \\
        software-properties-common \\
        build-essential \\
        cmake \\
        python3 \\
        python3-pip \\
        python3-dev \\
        python3-venv \\
        python3-numpy \\
        python3-toml \\
        python3-jinja2 \\
        python3-empy \\
        python3-packaging \\
        python3-requests \\
        python3-yaml \\
        bc \\
        screen \\
        vim \\
        netcat-openbsd \\
        iputils-ping \\
        net-tools \\
        openssh-client

    echo '=== Installing PX4 SITL dependencies ==='
    apt-get install -y \\
        ninja-build \\
        exiftool \\
        astyle \\
        genromfs \\
        libgstreamer1.0-dev \\
        libgstreamer-plugins-base1.0-dev \\
        gstreamer1.0-plugins-base \\
        gstreamer1.0-plugins-good \\
        gstreamer1.0-plugins-bad \\
        gstreamer1.0-plugins-ugly \\
        libprotobuf-dev \\
        protobuf-compiler \\
        libeigen3-dev \\
        libopencv-dev \\
        libxml2-utils \\
        unzip \\
        zip || true

    echo '=== Installing Gazebo Classic ==='
    # Add Gazebo repository
    curl -sSL https://packages.osrfoundation.org/gazebo.gpg -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable jammy main' > /etc/apt/sources.list.d/gazebo-stable.list
    apt-get update
    apt-get install -y gazebo libgazebo-dev || true

    echo '=== Installing Python dependencies ==='
    pip3 install --upgrade pip
    pip3 install \\
        pyserial \\
        pymavlink \\
        MAVProxy \\
        pexpect \\
        future \\
        empy==3.3.4 \\
        toml \\
        jsonschema \\
        jinja2 \\
        pyros-genmsg \\
        kconfiglib

    echo '=== Installing mavsdk and project dependencies ==='
    pip3 install \\
        mavsdk \\
        grpcio \\
        grpcio-tools \\
        aiohttp \\
        fastapi \\
        uvicorn \\
        sdnotify \\
        requests

    cd /root

    echo '=== Cloning MARLIN repository ==='
    git clone ${MARLIN_REPO_URL} mavsdk_drone_show
    cd mavsdk_drone_show
    git checkout ${MARLIN_BRANCH}

    echo '=== Setting up Python virtual environment ==='
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate

    cd /root

    echo '=== Cloning PX4-Autopilot repository ==='
    git clone https://github.com/PX4/PX4-Autopilot.git
    cd PX4-Autopilot
    git checkout -f ${PX4_BRANCH}
    git clean -fd
    git submodule update --init --recursive --force

    echo '=== Building PX4 SITL ==='
    DONT_RUN=1 make px4_sitl gazebo-classic

    echo '=== Setting up environment ==='
    echo 'source /root/PX4-Autopilot/Tools/simulation/gazebo-classic/setup_gazebo.bash /root/PX4-Autopilot /root/PX4-Autopilot/build/px4_sitl_default' >> /root/.bashrc
    echo 'export ROS_PACKAGE_PATH=\$ROS_PACKAGE_PATH:/root/PX4-Autopilot:/root/PX4-Autopilot/Tools/simulation/gazebo-classic/sitl_gazebo-classic' >> /root/.bashrc

    echo '=== Installing mavlink-routerd ==='
    cd /root
    apt-get install -y meson
    git clone https://github.com/mavlink-router/mavlink-router.git
    cd mavlink-router
    git submodule update --init --recursive
    meson setup build .
    ninja -C build
    ninja -C build install

    echo '=== Verifying installation ==='
    python3 -c 'import mavsdk; print(\"mavsdk OK\")'
    python3 -c 'import sdnotify; print(\"sdnotify OK\")'
    ls -la /root/PX4-Autopilot/build/px4_sitl_default/bin/px4

    echo '=== Cleaning up to reduce image size ==='
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -rf /root/.cache/pip/*

    echo '=== PX4 installation complete ==='
"

log_info "Committing container to image: $OUTPUT_IMAGE"
docker commit -m "PX4 SITL image for drone show simulation" "$TEMP_CONTAINER" "$OUTPUT_IMAGE"

# Also tag as drone-template:latest for compatibility
log_info "Tagging as drone-template:latest"
docker tag "$OUTPUT_IMAGE" drone-template:latest

# Remove the trap since we're about to clean up manually
trap - EXIT
cleanup

log_info "=============================================="
log_info " PX4 Docker image created successfully!"
log_info "=============================================="
echo ""
echo "Images created:"
echo "  - $OUTPUT_IMAGE"
echo "  - drone-template:latest"
echo ""
echo "Usage with create_dockers.sh:"
echo "  bash multiple_sitl/create_dockers.sh 5 --autopilot px4"
echo ""
echo "Manual testing:"
echo "  docker run -it --rm $OUTPUT_IMAGE bash"
echo "  cd ~/PX4-Autopilot && HEADLESS=1 make px4_sitl gazebo-classic"
echo ""
