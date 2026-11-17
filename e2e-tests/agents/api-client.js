/**
 * KoCourt API Client for agent testing.
 * Thin wrapper around fetch with auth token management.
 */
const BASE = process.env.E2E_API_BASE_URL || 'https://www.kocourt.com/api';

class ApiClient {
  constructor(name) {
    this.name = name;
    this.token = null;
    this.userId = null;
    this.userName = null;
  }

  /** Authenticate via demo OTP (code=1234) */
  async login(phone, name) {
    await this.post('/auth/send-otp', { phone });
    const data = await this.post('/auth/verify-otp', { phone, otp: '1234' });
    this.token = data.token;
    this.userId = data.user?.id;
    this.userName = data.user?.name;
    if (name && (!this.userName || this.userName === phone)) {
      await this.put('/auth/profile', { name });
      this.userName = name;
    }
    return data;
  }

  async get(path) {
    return this._request('GET', path);
  }

  async post(path, body) {
    return this._request('POST', path, body);
  }

  async put(path, body) {
    // Method tunneling: PUT sent as POST + header (LiteSpeed workaround)
    return this._request('POST', path, body, { 'X-HTTP-Method-Override': 'PUT' });
  }

  async del(path, body) {
    // Method tunneling: DELETE sent as POST + header
    return this._request('POST', path, body, { 'X-HTTP-Method-Override': 'DELETE' });
  }

  async _request(method, path, body, extraHeaders = {}) {
    const url = `${BASE}${path}`;
    const headers = {
      'Content-Type': 'application/json',
      ...extraHeaders,
    };
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`;

    const opts = { method, headers };
    if (body && method !== 'GET') opts.body = JSON.stringify(body);

    const res = await fetch(url, opts);
    const text = await res.text();
    let data;
    try { data = JSON.parse(text); } catch { data = { raw: text }; }

    if (!res.ok) {
      const err = new Error(`${res.status} ${method} ${path}: ${text.slice(0, 200)}`);
      err.status = res.status;
      err.data = data;
      throw err;
    }
    return data;
  }
}

module.exports = { ApiClient, BASE };
