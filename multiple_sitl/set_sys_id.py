#!/usr/bin/env python3
"""
Set System ID for PX4 or ArduPilot SITL.

For PX4: Modifies the rcS file to set MAV_SYS_ID.
For ArduPilot: The system ID is set via --sysid parameter in sim_vehicle.py,
               but we also create a parameter file for reference.

Usage:
    python3 set_sys_id.py --autopilot px4
    python3 set_sys_id.py --autopilot ardupilot
    python3 set_sys_id.py  # defaults to px4
"""

import os
import re
import argparse

# Directory where the .hwID files are
HWID_DIR = os.path.expanduser('~/mavsdk_drone_show')

# PX4 rcS file path
PX4_RCS_FILE = os.path.expanduser('~/PX4-Autopilot/build/px4_sitl_default/etc/init.d-posix/rcS')

# ArduPilot parameter file directory
ARDUPILOT_PARAM_DIR = os.path.expanduser('~/ardupilot/Tools/autotest')


def find_hwid():
    """Find and extract hardware ID from .hwID file."""
    hwid_file = next((f for f in os.listdir(HWID_DIR) if f.endswith('.hwID')), None)
    if not hwid_file:
        raise FileNotFoundError('.hwID file not found in ' + HWID_DIR)
    hwid = hwid_file.split('.')[0]
    print(f"Found .hwID file with ID: {hwid}")
    return hwid


def set_px4_sysid(hwid):
    """Set MAV_SYS_ID in PX4 rcS file."""
    print(f"Setting PX4 MAV_SYS_ID to {hwid}")

    if not os.path.exists(PX4_RCS_FILE):
        raise FileNotFoundError(f"PX4 rcS file not found: {PX4_RCS_FILE}")

    with open(PX4_RCS_FILE, 'r') as f:
        rcs_content = f.readlines()

    # Remove existing MAV_SYS_ID lines that don't match our hwid
    rcs_content = [
        line for line in rcs_content
        if not (re.match(r'param set MAV_SYS_ID \d+', line) and not line.strip().endswith(hwid))
    ]

    # Find the index of the default MAV_SYS_ID line
    index = next(
        (i for i, line in enumerate(rcs_content) if 'param set MAV_SYS_ID $((px4_instance+1))' in line),
        None
    )

    if index is not None:
        if any(f'param set MAV_SYS_ID {hwid}' in line for line in rcs_content):
            print(f"param set MAV_SYS_ID {hwid} is already in the file.")
        else:
            print(f"Adding line: param set MAV_SYS_ID {hwid}")
            rcs_content.insert(index + 1, f'param set MAV_SYS_ID {hwid}\n')
    else:
        raise ValueError("Couldn't find the line 'param set MAV_SYS_ID $((px4_instance+1))'")

    with open(PX4_RCS_FILE, 'w') as f:
        f.writelines(rcs_content)

    print("PX4 MAV_SYS_ID set successfully")


def set_ardupilot_sysid(hwid):
    """
    Set SYSID_THISMAV for ArduPilot.

    Note: For ArduPilot SITL, the system ID is primarily set via the --sysid
    parameter when launching sim_vehicle.py. This function creates a parameter
    file for reference and potential use with custom configurations.
    """
    print(f"Setting ArduPilot SYSID_THISMAV to {hwid}")

    # Ensure directory exists
    os.makedirs(ARDUPILOT_PARAM_DIR, exist_ok=True)

    # Create a drone-specific parameter file
    param_file = os.path.join(ARDUPILOT_PARAM_DIR, f'drone_{hwid}_params.parm')

    # Write parameter file
    params = [
        f"# Auto-generated parameters for drone {hwid}",
        f"# MAVSDK Drone Show - ArduPilot SITL",
        f"SYSID_THISMAV={hwid}",
        "",  # Empty line at end
    ]

    with open(param_file, 'w') as f:
        f.write('\n'.join(params))

    print(f"ArduPilot parameter file created: {param_file}")

    # Also create an environment variable hint file for the startup script
    env_file = os.path.join(HWID_DIR, '.ardupilot_sysid')
    with open(env_file, 'w') as f:
        f.write(hwid)

    print(f"ArduPilot SYSID hint file created: {env_file}")
    print("ArduPilot SYSID_THISMAV set successfully")
    print(f"Note: System ID {hwid} will be passed via --sysid parameter to sim_vehicle.py")


def main():
    parser = argparse.ArgumentParser(
        description='Set System ID for PX4 or ArduPilot SITL',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 set_sys_id.py --autopilot px4
    python3 set_sys_id.py --autopilot ardupilot
    python3 set_sys_id.py  # defaults to px4 for backward compatibility
        """
    )
    parser.add_argument(
        '--autopilot',
        choices=['px4', 'ardupilot'],
        default='px4',
        help='Autopilot type (default: px4)'
    )
    args = parser.parse_args()

    print(f"Autopilot type: {args.autopilot}")

    hwid = find_hwid()

    if args.autopilot == 'px4':
        set_px4_sysid(hwid)
    else:
        set_ardupilot_sysid(hwid)


if __name__ == '__main__':
    main()
