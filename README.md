# MARLIN

**All-in-One Drone Show & Smart Swarm Framework for PX4 & ArduPilot**

[![Version](https://img.shields.io/badge/version-0.1-blue.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-PolyForm%20Dual-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11%20%7C%203.12%20%7C%203.13-blue.svg)](docs/guides/python-compatibility.md)

MARLIN is a unified platform for PX4 and ArduPilot-based drone performances and intelligent swarm missions. Whether you want to run pre-planned, decentralized drone shows using SkyBrush outputs or orchestrate live, collaborative swarms with leader–follower clustering, MARLIN has you covered.

---

## Table of Contents

- [Overview](#overview)
- [Demo Videos](#demo-videos)
- [Key Features](#key-features)
- [Getting Started](#getting-started)
  - [Python Requirements](#python-requirements)
  - [Quick Start (SITL Demo)](#quick-start-sitl-demo)
  - [Advanced Configuration](#advanced-configuration)
  - [Real Hardware Deployment](#real-hardware-deployment)
- [Documentation](#documentation)
- [Version & Changelog](#version--changelog)

---

## Overview

MARLIN combines three core components into a single, cohesive package:

### 1. Drone Side
- Runs on any Linux-based autopilot platform (Raspberry Pi, NVIDIA Jetson, or similar)
- Handles MAVSDK integration, local trajectory execution, and failsafe monitoring
- Dynamic formation logic and autonomous operation

### 2. Cloud Side (Optional Backend)
- Hosts formation-planning engine, mission dispatcher, and WebSocket/MAVLink router
- Provides global setpoint management, three-way startup handshake, and health-check services
- Deploy on cloud VM (Ubuntu 22.04/23.04) or on-premises server

### 3. Frontend (React Dashboard)
- Full-featured React GUI for real-time monitoring and control
- Upload offline "ShowMode" trajectories (CSV/JSON from SkyBrush)
- Visualize live positions, assign leaders/followers, and trigger mission modes
- **3D Trajectory Planning** with interactive waypoints and terrain elevation
- Supports both Drone-Show mode and Smart-Swarm mode

**In short, MARLIN is one package for:**
- **Offline Drone Shows**: Pre-planned, synchronized formations from SkyBrush CSV
- **Smart Swarm Missions**: Decentralized leader–follower missions with robust failsafe handling

---

## Key Features

### All-in-One Architecture
- Shared Docker image and codebase for offline shows and live swarm missions
- Single command-line interface and unified React dashboard
- Streamlined deployment workflow

### Offline Drone-Show Mode
- Converts SkyBrush CSV/JSON into MAVSDK-compatible "ShowMode" files
- Global setpoint propagation for perfect synchronization (10–100+ drones)
- Preflight sanity checks (battery, GPS lock, ESC health)

### Smart Swarm Mode (Live, Decentralized)
- Clustered leader–follower architecture with Kalman-filter state estimation
- Automatic leader failure detection and re-election
- Dynamic formation reshaping and per-drone role changes
- In-flight failsafe monitors for communication, altimeter, ESC health

### Stable Startup Handshake
- Three-way acknowledgement chain (Drone ⇄ Autopilot ⇄ MAVSDK ⇄ GCS)
- "OK-to-Start" broadcast prevents premature launches
- Guaranteed readiness before takeoff

### Robustness & Performance
- Race-condition fixes under high CPU load
- Emergency-land command reliability during mode transitions
- Network buffer tuning for large-scale simulations (100+ drones)

### Professional React Dashboard
- Live monitoring: position, battery, mode, failsafe status per drone
- Mission upload interface for offline trajectories or real-time swarm commands
- **3D Trajectory Planning**: Interactive waypoint creation with real terrain elevation
  - Professional trajectory management with speed optimization
  - Requires Mapbox access token for full functionality
- Formation editor (drag-and-drop) - coming soon
- REST API endpoints via MAVLink2REST

### Automated Docker Environment
- Support for both **PX4** and **ArduPilot** autopilots
- Build scripts for Docker images (`build_px4_image.sh`, `build_ardupilot_image.sh`)
- Images include: MAVSDK, MAVLink Router, MAVProxy, Gazebo
- Auto hardware-ID detection
- Dynamic container creation with `--autopilot px4` or `--autopilot ardupilot`

### Mission Configuration Tools
- SkyBrush CSV → MARLIN converter script
- JSON-based mission/formation files with validators
- Parameter tuning utilities for leader election, Kalman filters, failsafe timeouts

---

## Getting Started

### Python Requirements

**MARLIN requires Python 3.11, 3.12, or 3.13.** The latest Raspberry Pi OS includes Python 3.13 and is fully supported.

📖 See [Python Compatibility Guide](docs/guides/python-compatibility.md) for details and troubleshooting.

### Quick Start (SITL Demo)

The fastest way to try MARLIN is with our SITL (Software-In-The-Loop) demo:

📖 **[SITL Demo Guide](docs/guides/sitl-comprehensive.md)** - Complete step-by-step setup

This guide covers:
- Docker image build/load commands
- Environment setup (`setup_environment.sh`, `create_dockers.sh`)
- Network, MAVLink Router, Netbird VPN configuration
- React dashboard startup (`linux_dashboard_start.sh --sitl`)
- Uploading offline trajectories or launching live swarm missions
- 3D Trajectory Planning setup (add Mapbox access token to `.env`)

#### Building Docker Images

The build scripts require an SSH deploy key to clone the private repository.

**Setup Deploy Key:**

1. Get your deploy key from your team or generate a new one following [GitHub Deploy Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys)

2. Create the key file:
   ```bash
   nano ~/.ssh/marlin_deploy_key
   ```

3. Paste your deploy key content (the entire private key including the header and footer):
   ```
   -----BEGIN OPENSSH PRIVATE KEY-----
   b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAA...
   ...
   -----END OPENSSH PRIVATE KEY-----
   ```

4. Save the file and set correct permissions:
   ```bash
   chmod 600 ~/.ssh/marlin_deploy_key
   ```

**Build Images:**

```bash
# Using environment variable
export MARLIN_SSH_KEY="$(cat ~/.ssh/marlin_deploy_key)"
bash tools/build_px4_image.sh
bash tools/build_ardupilot_image.sh

# Using command line argument
bash tools/build_px4_image.sh --ssh-key "$(cat ~/.ssh/marlin_deploy_key)"
bash tools/build_ardupilot_image.sh --ssh-key "$(cat ~/.ssh/marlin_deploy_key)"
```

#### Creating Drone Containers

```bash
# PX4 drones (default)
bash multiple_sitl/create_dockers.sh 5 --autopilot px4

# ArduPilot drones
bash multiple_sitl/create_dockers.sh 5 --autopilot ardupilot
```

**Quick Start Option:**
📖 **[Quick Start Guide](docs/quickstart/sitl-demo.md)** - Essential steps only (condensed version)

### Advanced Configuration

For custom repositories, production SITL deployments, or advanced scenarios:

📖 **[Advanced SITL Guide](docs/guides/advanced-sitl.md)** - Custom configuration and environment variables

> ⚠️ **Advanced configuration requires good understanding of Git, Docker, and Linux**

### Real Hardware Deployment

**⚠️ IMPORTANT:** Deploying MARLIN on real drones requires:
- Deep understanding of flight control systems and safety protocols
- Aviation regulations compliance
- Extensive testing in controlled environments
- Professional drone operation knowledge and certifications
- Additional hardware setup, networking, and safety configurations

---

## Documentation

### 📚 Documentation Index

All project documentation is organized in the `docs/` folder:

📖 **[Documentation Index](docs/README.md)** - Complete guide to all available documentation

### Quick Links

| Category | Description | Link |
|----------|-------------|------|
| **Quick Start** | Fast SITL demo setup | [docs/quickstart/](docs/quickstart/) |
| **Guides** | Comprehensive setup and configuration | [docs/guides/](docs/guides/) |
| **Features** | Detailed feature documentation | [docs/features/](docs/features/) |
| **Hardware** | Hardware-specific guides | [docs/hardware/](docs/hardware/) |
| **API** | API documentation | [docs/api/](docs/api/) |
| **Versioning** | Version management workflow | [docs/VERSIONING.md](docs/VERSIONING.md) |

### Key Guides

- **[SITL Comprehensive Guide](docs/guides/sitl-comprehensive.md)** - Full SITL setup and usage
- **[Advanced SITL Configuration](docs/guides/advanced-sitl.md)** - Custom deployments
- **[CSV Migration Guide](docs/guides/csv-migration.md)** - Configuration format migration
- **[Python Compatibility](docs/guides/python-compatibility.md)** - Python version requirements
- **[Swarm Trajectory Feature](docs/features/swarm-trajectory.md)** - Smart swarm capabilities
- **[Origin System](docs/features/origin-system.md)** - Coordinate system implementation
- **[Control Modes and Coordinates](docs/control-modes-and-coordinates.md)** - Comprehensive control modes, coordinate systems, and Phase 2 reference

---

