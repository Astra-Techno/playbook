/**
 * Test personas — simulated users with different roles and behaviors.
 * Each persona logs in with demo OTP and performs role-appropriate actions.
 */
const { ApiClient } = require('./api-client');

// Phone numbers for test personas (demo OTP mode: code=1234)
const PHONES = {
  owner:   '9994439081',  // Admin/owner (Mathavan, user ID 1)
  player1: '9000000099',  // Test player 1
  player2: '9000000098',  // Test player 2
  player3: '9000000097',  // Test player 3
  staff1:  '9000000096',  // Test staff member
};

async function createOwner() {
  const client = new ApiClient('Owner:Mathavan');
  await client.login(PHONES.owner, 'Mathavan');
  return client;
}

async function createPlayer(index = 1) {
  const phone = PHONES[`player${index}`] || `900000009${index}`;
  const name = `TestPlayer${index}`;
  const client = new ApiClient(`Player:${name}`);
  await client.login(phone, name);
  return client;
}

async function createStaff() {
  const client = new ApiClient('Staff:TestStaff');
  await client.login(PHONES.staff1, 'TestStaff');
  return client;
}

/** Generate a future time slot that won't collide */
function futureSlot(daysAhead = 2, hour = 10) {
  const d = new Date();
  d.setDate(d.getDate() + daysAhead);
  const date = d.toISOString().split('T')[0];
  const start = `${date} ${String(hour).padStart(2, '0')}:00:00`;
  const end = `${date} ${String(hour + 1).padStart(2, '0')}:00:00`;
  return { date, start, end };
}

/** Pick random item from array */
function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Random delay to simulate human behavior (200-800ms) */
function humanDelay() {
  return new Promise(r => setTimeout(r, 200 + Math.random() * 600));
}

module.exports = { createOwner, createPlayer, createStaff, futureSlot, pick, humanDelay, PHONES };
