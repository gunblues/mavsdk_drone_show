//app/dashboard/drone-dashboard/src/components/SidebarMenu.js
import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  FaGlobe,
  FaTachometerAlt,
  FaCog,
  FaList,
  FaRoute,
  FaProjectDiagram,
  FaGithub,
  FaGem,
  FaBars,
  FaTimes
} from 'react-icons/fa';
import { useTheme } from '../hooks/useTheme';
import '../styles/SidebarMenu.css';
import valtecLogo from '../assets/valtec_logo.png';

const SidebarMenu = ({ collapsed, onToggle }) => {
  const { isDark } = useTheme();
  const location = useLocation();
  const [localCollapsed, setLocalCollapsed] = useState(window.innerWidth < 768);
  const [activeTooltip, setActiveTooltip] = useState(null);

  const isCollapsed = collapsed !== undefined ? collapsed : localCollapsed;
  const handleToggle = onToggle || setLocalCollapsed;

  const menuItems = [
    { to: '/connected-drones', icon: FaList, label: 'Connected Drones', category: 'main' },
    { to: '/dashboard', icon: FaTachometerAlt, label: 'Dashboard', category: 'main' },
    { to: '/mission-config', icon: FaCog, label: 'Mission Config', category: 'main' },
    { to: '/swarm-design', icon: FaProjectDiagram, label: 'Swarm Design', category: 'workflow' },
    { to: '/trajectory-planning', icon: FaRoute, label: 'Trajectory Planning', category: 'workflow' },
    { to: '/swarm-trajectory', icon: FaGlobe, label: 'Swarm Trajectory', category: 'workflow' },
    { to: '/manage-drone-show', icon: FaGem, label: 'Drone Show Design', category: 'design' },
    { to: '/custom-show', icon: FaGithub, label: 'Custom Show', category: 'design' },
    { to: '/globe-view', icon: FaGlobe, label: 'Drone 3D View', category: 'visualization' }
  ];

  const handleTooltip = (label) => {
    if (isCollapsed) {
      setActiveTooltip(label);
      setTimeout(() => setActiveTooltip(null), 2000);
    }
  };

  const isActive = (path) => {
    if (path === '/') {
      return location.pathname === '/';
    }
    return location.pathname.startsWith(path);
  };

  return (
    <div className={`valtec-sidebar ${isCollapsed ? 'collapsed' : 'expanded'} ${isDark ? 'dark' : 'light'}`}>
      {/* Toggle Button */}
      <button
        className="sidebar-toggle"
        onClick={() => handleToggle(!isCollapsed)}
        aria-label="Toggle Sidebar"
      >
        {isCollapsed ? <FaBars /> : <FaTimes />}
      </button>

      {/* Header Section with Logo */}
      <div className="sidebar-header">
        {!isCollapsed ? (
          <div className="header-expanded">
            <div className="brand">
              <div className="brand-logo">
                <img src={valtecLogo} alt="Valtec" className="logo-image" />
              </div>
              <div className="brand-text">
                <h1 className="brand-name">Valtec</h1>
              </div>
            </div>
          </div>
        ) : (
          <div className="header-collapsed">
            <div className="brand-logo-collapsed">
              <img src={valtecLogo} alt="Valtec" className="logo-image-collapsed" />
            </div>
          </div>
        )}
      </div>

      {/* Navigation Menu */}
      <nav className="sidebar-nav">
        <div className="nav-section">
          {menuItems.map((item) => {
            const IconComponent = item.icon;
            const active = isActive(item.to);
            return (
              <Link
                key={item.to}
                to={item.to}
                className={`nav-item ${isCollapsed ? 'collapsed' : ''} ${active ? 'active' : ''}`}
                onMouseEnter={() => handleTooltip(item.label)}
                onMouseLeave={() => setActiveTooltip(null)}
                data-tooltip={item.label}
              >
                <div className="nav-icon-wrapper">
                  <IconComponent className="nav-icon" />
                </div>
                {!isCollapsed && <span className="nav-label">{item.label}</span>}
                {active && <div className="active-indicator" />}

                {/* Tooltip for collapsed state */}
                {isCollapsed && activeTooltip === item.label && (
                  <div className="nav-tooltip">{item.label}</div>
                )}
              </Link>
            );
          })}
        </div>
      </nav>

    </div>
  );
}

export default SidebarMenu;
