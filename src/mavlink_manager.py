import subprocess
import logging

class MavlinkManager:
    def __init__(self, params, drone_config):
        self.params = params
        self.drone_config = drone_config
        self.mavlink_router_process = None
        logging.info("Initialized MavlinkManager")

    def initialize(self):
        try:
            hw_id = int(self.drone_config.config.get('hw_id', 1))

            if self.params.sim_mode:
                logging.info("Sim mode is enabled. Connecting to SITL...")

                if self.params.AUTOPILOT_TYPE == 'ardupilot':
                    # ArduPilot SITL: Connect to TCP port 5760 (no mavproxy mode)
                    # Port = 5760 + (instance * 10), instance = hw_id - 1
                    instance = hw_id - 1
                    tcp_port = self.params.ARDUPILOT_SITL_BASE_PORT + (instance * self.params.ARDUPILOT_SITL_PORT_INCREMENT)
                    mavlink_source = f"127.0.0.1:{tcp_port}"
                    logging.info(f"ArduPilot SITL - using TCP source: {mavlink_source}")
                else:
                    # PX4 SITL: Listen on UDP port 14550
                    if self.params.default_sitl:
                        mavlink_source = f"0.0.0.0:{self.params.sitl_port}"
                    else:
                        mavlink_source = f"0.0.0.0:{self.drone_config.config['mavlink_port']}"
                    logging.info(f"PX4 SITL - using UDP source: {mavlink_source}")
            else:
                if self.params.serial_mavlink:
                    logging.info("Real mode is enabled. Connecting to Pixhawk via serial...")
                    mavlink_source = f"{self.drone_config.get_serial_port()}:{self.drone_config.get_baudrate()}"
                else:
                    logging.info("Real mode is enabled. Connecting to Pixhawk via UDP...")
                    mavlink_source = f"127.0.0.1:{self.params.hw_udp_port}"

            logging.info(f"Using MAVLink source: {mavlink_source}")

            endpoints = [f"-e {device}" for device in self.params.extra_devices]

            if self.params.sim_mode:
                if self.params.AUTOPILOT_TYPE == 'ardupilot':
                    # ArduPilot SITL: Router must forward to MAVSDK port (ArduPilot only exposes TCP)
                    endpoints.append(f"-e 127.0.0.1:{self.params.mavsdk_port}")
                    logging.info(f"ArduPilot SITL: Adding MAVSDK endpoint 127.0.0.1:{self.params.mavsdk_port}")
                else:
                    # PX4 SITL: Already sends to 14550 and 14540, no need to add MAVSDK endpoint
                    pass
            else:
                endpoints.append(f"-e 127.0.0.1:{self.params.mavsdk_port}")

            if self.params.shared_gcs_port:
                endpoints.append(f"-e {self.params.GCS_IP}:{self.params.gcs_mavlink_port}")
            else:
                endpoints.append(f"-e {self.params.GCS_IP}:{int(self.drone_config.config['mavlink_port'])}")

            # -t 0 disables TCP listening (prevents conflict with ArduPilot's TCP port 5760)
            mavlink_router_cmd = "mavlink-routerd -t 0 " + ' '.join(endpoints) + ' ' + mavlink_source
            logging.info(f"Starting MAVLink router with command: {mavlink_router_cmd}")

            self.mavlink_router_process = subprocess.Popen(mavlink_router_cmd, shell=True)
            logging.info("MAVLink router process started")
        except Exception as e:
            logging.error(f"An error occurred in initialize(): {e}")

    def terminate(self):
        try:
            if self.mavlink_router_process:
                self.mavlink_router_process.terminate()
                logging.info("MAVLink router process terminated")
            else:
                logging.warning("MAVLink router process is not running")
        except Exception as e:
            logging.error(f"An error occurred in terminate(): {e}")
