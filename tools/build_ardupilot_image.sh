#!/bin/bash
# =============================================================================
# Script Name: build_ardupilot_image.sh
# Description: Build ArduPilot Docker image for drone show SITL simulation
# Author: MAVSDK Drone Show Team
# Date: December 2024
# =============================================================================
#
# This script builds a Docker image with ArduPilot SITL installed, based on
# the existing drone-template image or a fresh Ubuntu 22.04 base.
#
# Usage:
#   bash tools/build_ardupilot_image.sh [OPTIONS]
#
# Options:
#   --base IMAGE          Base Docker image (default: drone-template:latest or ubuntu:22.04)
#   --output IMAGE        Output image name (default: drone-template-ardupilot:latest)
#   --from-scratch        Build from ubuntu:22.04 instead of drone-template
#   --vehicle VEHICLE     ArduPilot vehicle type (default: ArduCopter)
#   --help                Show this help message
#
# Examples:
#   # Build from existing drone-template (faster, includes mavsdk_drone_show)
#   bash tools/build_ardupilot_image.sh
#
#   # Build from scratch (includes everything)
#   bash tools/build_ardupilot_image.sh --from-scratch
#
#   # Custom output image name
#   bash tools/build_ardupilot_image.sh --output mycompany-ardupilot:v1.0
#
# =============================================================================

set -euo pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
BASE_IMAGE="drone-template:latest"
OUTPUT_IMAGE="drone-template-ardupilot:latest"
FROM_SCRATCH=false
VEHICLE="ArduCopter"

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

Build ArduPilot Docker image for drone show SITL simulation.

Options:
  --base IMAGE          Base Docker image (default: drone-template:latest)
  --output IMAGE        Output image name (default: drone-template-ardupilot:latest)
  --from-scratch        Build from ubuntu:22.04 instead of drone-template
  --vehicle VEHICLE     ArduPilot vehicle type (default: ArduCopter)
  --help                Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --from-scratch
  $(basename "$0") --output mycompany-ardupilot:v1.0
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE_IMAGE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_IMAGE="$2"
            shift 2
            ;;
        --from-scratch)
            FROM_SCRATCH=true
            BASE_IMAGE="ubuntu:22.04"
            shift
            ;;
        --vehicle)
            VEHICLE="$2"
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

echo "=============================================="
echo " ArduPilot Docker Image Builder v${SCRIPT_VERSION}"
echo "=============================================="
echo ""
echo "Configuration:"
echo "  Base Image: $BASE_IMAGE"
echo "  Output Image: $OUTPUT_IMAGE"
echo "  From Scratch: $FROM_SCRATCH"
echo "  Vehicle: $VEHICLE"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if base image exists
if ! docker image inspect "$BASE_IMAGE" &> /dev/null; then
    if [ "$FROM_SCRATCH" = true ]; then
        log_info "Pulling base image: $BASE_IMAGE"
        docker pull "$BASE_IMAGE"
    else
        log_error "Base image '$BASE_IMAGE' not found. Use --from-scratch to build from ubuntu:22.04"
        exit 1
    fi
fi

# Create temporary container name
TEMP_CONTAINER="ardupilot-build-$(date +%s)"

log_info "Creating temporary container: $TEMP_CONTAINER"
docker run --name "$TEMP_CONTAINER" -d "$BASE_IMAGE" tail -f /dev/null

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary container..."
    docker rm -f "$TEMP_CONTAINER" 2>/dev/null || true
}
trap cleanup EXIT

log_info "Installing ArduPilot and dependencies inside container..."

# Install ArduPilot inside the container
docker exec "$TEMP_CONTAINER" bash -c '
    set -e

    export DEBIAN_FRONTEND=noninteractive

    echo "=== Updating package lists ==="
    apt-get update

    echo "=== Installing ArduPilot SITL dependencies ==="
    # These are the dependencies needed for ArduPilot SITL (manually listed since install-prereqs refuses root)
    apt-get install -y \
        git \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv \
        python3-numpy \
        python3-matplotlib \
        python3-serial \
        python3-opencv \
        python3-wxgtk4.0 \
        python3-lxml \
        python3-scipy \
        wget \
        curl \
        sudo \
        lsb-release \
        software-properties-common \
        build-essential \
        ccache \
        gawk \
        g++ \
        gcc \
        make \
        cmake \
        libtool \
        libxml2-dev \
        libxslt1-dev \
        bc \
        screen \
        xterm || true

    echo "=== Installing Python dependencies for SITL ==="
    pip3 install --upgrade pip
    pip3 install pexpect future pymavlink MAVProxy empy==3.3.4 dronecan packaging

    echo "=== Installing mavsdk_drone_show Python dependencies ==="
    # Always install key dependencies first
    pip3 install mavsdk grpcio grpcio-tools aiohttp fastapi uvicorn sdnotify pyserial requests

    # Then install from requirements.txt if available
    if [ -f /root/mavsdk_drone_show/requirements.txt ]; then
        pip3 install -r /root/mavsdk_drone_show/requirements.txt
    fi

    # Verify critical packages are installed
    echo "=== Verifying Python packages ==="
    python3 -c "import sdnotify" && echo "sdnotify OK"
    python3 -c "import mavsdk" && echo "mavsdk OK"

    cd /root

    echo "=== Cloning ArduPilot repository ==="
    if [ ! -d "ardupilot" ]; then
        git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
    else
        echo "ArduPilot already exists, updating..."
        cd ardupilot
        git pull
        git submodule update --init --recursive
        cd ..
    fi

    cd ardupilot

    echo "=== Building ArduCopter SITL ==="
    ./waf configure --board sitl
    ./waf copter

    echo "=== Adding sim_vehicle.py to PATH ==="
    echo "export PATH=\$PATH:/root/ardupilot/Tools/autotest" >> /root/.bashrc
    echo "export PATH=\$PATH:/root/ardupilot/Tools/autotest" >> /root/.profile

    echo "=== Verifying installation ==="
    ls -la /root/ardupilot/Tools/autotest/sim_vehicle.py
    python3 -c "import pexpect; print(\"pexpect OK\")"
    python3 -c "import pymavlink; print(\"pymavlink OK\")"

    echo "=== Cleaning up to reduce image size ==="
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -rf /root/.cache/pip/*

    echo "=== ArduPilot installation complete ==="
'

log_info "Committing container to image: $OUTPUT_IMAGE"
docker commit -m "ArduPilot SITL image for drone show simulation" "$TEMP_CONTAINER" "$OUTPUT_IMAGE"

# Remove the trap since we're about to clean up manually
trap - EXIT
cleanup

log_info "=============================================="
log_info " ArduPilot Docker image created successfully!"
log_info "=============================================="
echo ""
echo "Image: $OUTPUT_IMAGE"
echo ""
echo "Usage with create_dockers.sh:"
echo "  bash multiple_sitl/create_dockers.sh 5 --autopilot ardupilot"
echo ""
echo "Manual testing:"
echo "  docker run -it --rm $OUTPUT_IMAGE bash"
echo "  cd ~/ardupilot && python3 Tools/autotest/sim_vehicle.py -v ArduCopter --no-mavproxy"
echo ""
