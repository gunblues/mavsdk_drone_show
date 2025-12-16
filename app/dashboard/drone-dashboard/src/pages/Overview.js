// src/pages/Overview.js
import React from 'react';
import PropTypes from 'prop-types';
import CommandSender from '../components/CommandSender'; // Import CommandSender
import '../styles/Overview.css';

const Overview = () => {
  return (
    <div className="overview-dashboard-container">
      <div className="mission-trigger-section">
        <CommandSender drones={[]} /> {/* Pass empty array for now */}
      </div>
    </div>
  );
};

Overview.propTypes = {
};

export default Overview;
