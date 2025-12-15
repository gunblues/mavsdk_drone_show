// src/components/CommandSender.js

import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import MissionTrigger from './MissionTrigger';
import { sendDroneCommand } from '../services/droneApiService';
import { toast } from 'react-toastify';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faRocket, faCog } from '@fortawesome/free-solid-svg-icons';
import {
  DRONE_MISSION_TYPES,
  DRONE_ACTION_TYPES,
  getCommandName,
} from '../constants/droneConstants';
import '../styles/CommandSender.css';
import { FIELD_NAMES } from '../constants/fieldMappings';

const CommandSender = ({ drones }) => {

  const [targetMode, setTargetMode] = useState('all'); // 'all' or 'selected'
  const [selectedDrones, setSelectedDrones] = useState([]);
  const [modalOpen, setModalOpen] = useState(false);
  const [currentCommandData, setCurrentCommandData] = useState(null);
  const [confirmationMessage, setConfirmationMessage] = useState('');
  const [loading, setLoading] = useState(false);

  // Handle new command from child components (MissionTrigger)
  const handleSendCommand = (commandData) => {
    let targetDronesList = 'All Drones';
    if (targetMode === 'selected') {
      if (selectedDrones.length === 0) {
        toast.error('No drones selected. Please select at least one drone.');
        return;
      }
      targetDronesList = selectedDrones.join(', ');
    }

    const missionName = getCommandName(commandData.missionType);
    setCurrentCommandData(commandData);
    setConfirmationMessage(
      `Command "${missionName}" will be sent to: ${targetDronesList}. Are you sure?`
    );
    setModalOpen(true);
  };

  // Confirm and send the command
  const handleConfirmSendCommand = async () => {
    if (currentCommandData) {
      setModalOpen(false);
      setLoading(true);
      try {
        const commandDataToSend = { ...currentCommandData };
        if (targetMode === 'selected') {
          commandDataToSend.target_drones = selectedDrones;
        }

        const response = await sendDroneCommand(commandDataToSend);

        if (response.success === true) {
          toast.success('Command sent successfully!');
        } else {
          toast.error(`Error sending command: ${response.message}`);
        }
      } catch (error) {
        console.error('Error sending command:', error);
        toast.error('Error sending command. Please check console for details.');
      } finally {
        setLoading(false);
        setCurrentCommandData(null);
      }
    }
  };

  // Cancel the command
  const handleCancelSendCommand = () => {
    setModalOpen(false);
    setCurrentCommandData(null);
  };

  // Drone selection functions
  const toggleDroneSelection = (droneId) => {
    setSelectedDrones((prev) =>
      prev.includes(droneId)
        ? prev.filter((id) => id !== droneId)
        : [...prev, droneId]
    );
  };

  const selectAllDrones = () => {
    const allDroneIds = drones.map((drone) => drone[FIELD_NAMES.HW_ID]);
    setSelectedDrones(allDroneIds);
  };

  const deselectAllDrones = () => {
    setSelectedDrones([]);
  };

  return (
    <div className="command-sender-container">
      {/* Tab Content */}
      <div className="tab-content">
        <MissionTrigger
            missionTypes={DRONE_MISSION_TYPES}
            onSendCommand={handleSendCommand}
        />
      </div>

      {/* Confirmation Modal - Rendered via Portal for proper viewport centering */}
      {modalOpen && ReactDOM.createPortal(
        <div className="modal-overlay" onClick={handleCancelSendCommand}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>Confirm Command</h3>
            <p>{confirmationMessage}</p>
            <div className="modal-actions">
              <button className="confirm-button" onClick={handleConfirmSendCommand}>
                Yes
              </button>
              <button className="cancel-button" onClick={handleCancelSendCommand}>
                No
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}

      {/* Loading Spinner */}
      {loading && (
        <div className="loading-overlay">
          <div className="loading-spinner"></div>
        </div>
      )}
    </div>
  );
};

CommandSender.propTypes = {
  drones: PropTypes.array.isRequired,
};

export default CommandSender;
