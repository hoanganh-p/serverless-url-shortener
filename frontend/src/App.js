import React, { useState, useEffect, useCallback } from 'react';
import './App.css';
import './styles/Navbar.css';
import UrlForm from './components/UrlForm';
import ResultDisplay from './components/ResultDisplay';
import ErrorMessage from './components/ErrorMessage';
import LoginForm from './components/LoginForm';
import RegisterForm from './components/RegisterForm';
import UserUrls from './components/UserUrls';
import { authService, urlService } from './services/api';

function App() {
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [username, setUsername] = useState(localStorage.getItem('username'));
  const [view, setView] = useState('home'); // 'home', 'login', 'register'
  const [userUrls, setUserUrls] = useState([]);

  const fetchHistory = useCallback(async () => {
    if (!token) return;
    try {
      const data = await urlService.getAll(token);
      setUserUrls(data);
    } catch (err) {
      console.error(err);
    }
  }, [token]);

  useEffect(() => {
    if (token) {
      fetchHistory();
    }
  }, [token, fetchHistory]);

  const handleLogin = async (username, password) => {
    setError('');
    try {
      const data = await authService.login(username, password);
      
      const token = data.token;
      setToken(token);
      localStorage.setItem('token', token);
      setUsername(username);
      localStorage.setItem('username', username);
      setView('home');
    } catch (err) {
      if (err.message === 'Failed to fetch') {
        setError('Connection error: Server not running or CORS blocked. Check console.');
      } else {
        setError(err.message);
      }
      console.error(err);
    }
  };

  const handleRegister = async (username, email, password) => {
    setError('');
    try {
      await authService.register(username, email, password);

      // After successful registration, auto login or switch to login page
      alert('Registration successful! Please login.');
      setView('login');
    } catch (err) {
      if (err.message === 'Failed to fetch') {
        setError('Connection error: Server not running or CORS blocked. Check console.');
      } else {
        setError(err.message);
      }
      console.error(err);
    }
  };

  const handleLogout = () => {
    setToken(null);
    localStorage.removeItem('token');
    setUsername(null);
    localStorage.removeItem('username');
    setUserUrls([]);
    setResult(null);
    setError('');
  };

  const handleShorten = async (longUrl) => {
    setError('');
    setResult(null);

    try {
      const data = await urlService.create(longUrl, token);
      setResult(data);
      if (token) {
        fetchHistory();
      }
    } catch (err) {
      setError('Cannot shorten URL');
      console.error(err);
    }
  };

  const handleDeleteUrl = async (shortCode) => {
    if (!window.confirm('Are you sure you want to delete this link?')) return;

    try {
      await urlService.delete(shortCode, token);
      setUserUrls(prevUrls => prevUrls.filter(url => url.shortCode !== shortCode));
    } catch (err) {
      console.error('Error deleting:', err);
      alert('An error occurred while connecting to the server.');
    }
  };

  return (
    <>
      <nav className="navbar">
        <h1 className="nav-brand" onClick={() => { setError(''); setView('home'); }}>URL Shortener</h1>
        <div>
          {!token ? (
            <>
              <button onClick={() => { setError(''); setView('login'); }} style={{ marginRight: '10px' }}>Login</button>
              <button onClick={() => { setError(''); setView('register'); }}>Register</button>
            </>
          ) : (
            <div className="nav-user">
              <span style={{ marginRight: '15px', fontWeight: '500' }}>Hello, {username}</span>
              <button onClick={handleLogout}>Logout</button>
            </div>
          )}
        </div>
      </nav>

      <div className="container main-container">
        <ErrorMessage message={error} />

        {view === 'home' && (
          <>
            <UrlForm onSubmit={handleShorten} />
            <ResultDisplay result={result} />
          </>
        )}

        {view === 'login' && <LoginForm onLogin={handleLogin} onSwitchToRegister={() => { setError(''); setView('register'); }} />}
        {view === 'register' && <RegisterForm onRegister={handleRegister} onSwitchToLogin={() => { setError(''); setView('login'); }} />}
      </div>

      {view === 'home' && token && (
        <div className="history-container">
          <UserUrls urls={userUrls} onDelete={handleDeleteUrl} />
        </div>
      )}
    </>
  );
}

export default App;
