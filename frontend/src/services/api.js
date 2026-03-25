// const AWS_API_URL = 'https://dr69b524xb.execute-api.ap-southeast-1.amazonaws.com/prod';
const AWS_API_URL = 'https://d2s5r61an6mtu1.cloudfront.net'; 
export const API_BASE = process.env.NODE_ENV === 'production' 
  ? AWS_API_URL 
  : "https://localhost:7241";

// Helper function to create headers containing token
const getHeaders = (token, hasBody = true) => {
  const headers = {};
  if (hasBody) {
    headers['Content-Type'] = 'application/json';
  }
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
};

// General response handling
const handleResponse = async (res) => {
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(data?.message || 'Request failed');
  }
  return data;
};

export const authService = {
  login: async (username, password) => {
    const res = await fetch(`${API_BASE}/api/auth/login`, {
      method: 'POST',
      headers: getHeaders(null),
      body: JSON.stringify({ username, password })
    });
    return handleResponse(res);
  },
  register: async (username, email, password) => {
    const res = await fetch(`${API_BASE}/api/auth/register`, {
      method: 'POST',
      headers: getHeaders(null),
      body: JSON.stringify({ username, email, password })
    });
    return handleResponse(res);
  }
};

export const urlService = {
  getAll: async (token) => {
    const res = await fetch(`${API_BASE}/api/url/user/all`, {
      method: 'GET',
      headers: getHeaders(token, false)
    });
    return handleResponse(res);
  },
  create: async (originalUrl, token) => {
    const res = await fetch(`${API_BASE}/api/url/create`, {
      method: 'POST',
      headers: getHeaders(token),
      body: JSON.stringify({ originalUrl })
    });
    return handleResponse(res);
  },
  delete: async (shortCode, token) => {
    const res = await fetch(`${API_BASE}/api/url/${shortCode}`, {
      method: 'DELETE',
      headers: getHeaders(token, false)
    });
    // Reuse handleResponse. If status is 204 (No Content), handleResponse returns null, which is valid.
    return handleResponse(res);
  }
};