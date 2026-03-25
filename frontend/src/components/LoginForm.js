import React, { useState } from 'react';
import '../styles/Auth.css';

const LoginForm = ({ onLogin, onSwitchToRegister }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    onLogin(username, password);
  };

  return (
    <div className="auth-container">
      <h2>Login</h2>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>Username:</label>
          <input 
            type="text" 
            value={username} 
            onChange={(e) => setUsername(e.target.value)} 
            required 
            placeholder="Enter username"
          />
        </div>
        <div className="form-group">
          <label>Password:</label>
          <input 
            type="password" 
            value={password} 
            onChange={(e) => setPassword(e.target.value)} 
            required 
            placeholder="Enter password"
          />
        </div>
        <button type="submit">Login</button>
      </form>
      <p className="auth-toggle-text">
        No account? <button type="button" className="auth-toggle-btn" onClick={onSwitchToRegister}>Register now</button>
      </p>
    </div>
  );
};

export default LoginForm;