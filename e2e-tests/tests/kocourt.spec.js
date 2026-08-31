const { test, expect } = require('@playwright/test');

const BASE = 'http://localhost:8787';
const API = 'http://localhost/playbook/backend';

// Helper: wait for Flutter app to fully render
async function waitForFlutter(page, timeout = 30000) {
  await page.waitForFunction(() => {
    return document.querySelector('flt-glass-pane') !== null ||
           document.querySelector('flutter-view') !== null;
  }, { timeout });
  await page.waitForTimeout(3000);
}

// Helper: take a screenshot and verify it's not blank
async function screenshotNotBlank(page, name) {
  const buffer = await page.screenshot({ path: `screenshots/${name}.png` });
  // A blank white page is typically very small or all same pixels
  expect(buffer.length).toBeGreaterThan(5000); // Non-trivial content
  return buffer;
}

// Helper: get auth token
async function getToken(page, phone = '9900000001') {
  const res = await page.request.post(`${API}/auth/verify-otp`, {
    data: { phone, otp: '1234' },
  });
  const data = await res.json();
  return data.token;
}

// ============================================================
// SECTION 1: Flutter App Visual Tests
// ============================================================
test.describe('Flutter App Visual Tests', () => {
  test.describe.configure({ mode: 'serial' });
  let page;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width: 400, height: 800 },
      permissions: ['geolocation'],
      geolocation: { latitude: 13.085, longitude: 80.210 },
    });
    page = await context.newPage();
  });

  test.afterAll(async () => { await page.close(); });

  test('01. App loads — canvas renders', async () => {
    await page.goto(BASE);
    await waitForFlutter(page);
    const el = await page.$('flt-glass-pane, flutter-view');
    expect(el).toBeTruthy();
    await screenshotNotBlank(page, '01-app-load');
  });

  test('02. Login screen renders', async () => {
    await page.goto(`${BASE}/#/login`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '02-login');
  });

  test('03. Home screen renders', async () => {
    await page.goto(`${BASE}/#/`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '03-home');
  });

  test('04. Court details renders', async () => {
    await page.goto(`${BASE}/#/court/2`);
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
    await screenshotNotBlank(page, '04-court-details');
  });

  test('05. Bookings screen renders', async () => {
    await page.goto(`${BASE}/#/bookings`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '05-bookings');
  });

  test('06. Profile screen renders', async () => {
    await page.goto(`${BASE}/#/profile`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '06-profile');
  });

  test('07. Feed screen renders', async () => {
    await page.goto(`${BASE}/#/feed`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '07-feed');
  });

  test('08. Matches screen renders', async () => {
    await page.goto(`${BASE}/#/matches`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '08-matches');
  });

  test('09. Notifications screen renders', async () => {
    await page.goto(`${BASE}/#/notifications`);
    await waitForFlutter(page);
    await screenshotNotBlank(page, '09-notifications');
  });

  test('10. Multiple screens have distinct content', async () => {
    // Take screenshots of different screens and verify they differ
    await page.goto(`${BASE}/#/login`);
    await waitForFlutter(page);
    const loginShot = await page.screenshot();

    await page.goto(`${BASE}/#/`);
    await waitForFlutter(page);
    const homeShot = await page.screenshot();

    await page.goto(`${BASE}/#/court/2`);
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
    const courtShot = await page.screenshot();

    // Different screens should produce different screenshots
    // Note: without auth, some screens may redirect to login — check at least login vs home differ
    const loginVsHome = Buffer.compare(loginShot, homeShot) !== 0;
    const homeVsCourt = Buffer.compare(homeShot, courtShot) !== 0;
    // At least one pair should differ (proves routing works)
    expect(loginVsHome || homeVsCourt).toBeTruthy();
  });
});

// ============================================================
// SECTION 2: API Integration Tests
// ============================================================
test.describe('API Integration Tests', () => {
  let token;
  let ownerToken;

  test.beforeAll(async ({ request }) => {
    // Get player token
    let res = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000001', otp: '1234' } });
    token = (await res.json()).token;

    // Get owner token
    res = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000010', otp: '1234' } });
    ownerToken = (await res.json()).token;
  });

  // --- Auth ---
  test('11. Send OTP', async ({ request }) => {
    const res = await request.post(`${API}/auth/send-otp`, { data: { phone: '9900000001' } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.message).toBe('OTP sent');
  });

  test('12. Verify OTP returns token + user', async ({ request }) => {
    const res = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000002', otp: '1234' } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.token).toBeDefined();
    expect(data.user.name).toBe('Priya Sharma');
  });

  test('13. Get profile', async ({ request }) => {
    const res = await request.get(`${API}/auth/profile`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.user.name).toBe('Ravi Kumar');
    expect(data.user.phone).toBe('9900000001');
  });

  test('14. Unauthenticated request is rejected', async ({ request }) => {
    const res = await request.get(`${API}/auth/profile`);
    expect(res.status()).toBe(401);
  });

  // --- Courts ---
  test('15. List courts', async ({ request }) => {
    const res = await request.get(`${API}/courts`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThanOrEqual(5);
  });

  test('16. Court detail', async ({ request }) => {
    const res = await request.get(`${API}/courts/2`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court.name).toContain('Smash Badminton');
    expect(data.court.amenities).toContain('Parking');
  });

  test('17. Sub-courts', async ({ request }) => {
    const res = await request.get(`${API}/sub-courts?court_id=2`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.sub_courts.length).toBe(3);
  });

  // --- Bookings ---
  test('18. List bookings', async ({ request }) => {
    const res = await request.get(`${API}/bookings?user_id=3`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThan(0);
    // Verify booking data structure
    const b = data.records[0];
    expect(b.start_time).toBeDefined();
    expect(b.court_name).toBeDefined();
    expect(b.status).toBe('confirmed');
  });

  test('19. Create booking', async ({ request }) => {
    const res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${token}` },
      data: (() => { const d = 10 + Math.floor(Math.random() * 20); const h = 6 + Math.floor(Math.random() * 12); return { court_id: 6, start_time: `2026-10-${String(d).padStart(2,'0')} ${String(h).padStart(2,'0')}:00:00`, end_time: `2026-10-${String(d).padStart(2,'0')} ${String(h+1).padStart(2,'0')}:00:00`, type: 'hourly', total_price: 250 }; })(),
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();
    // Store for cancel test
    test.info().annotations.push({ type: 'bookingId', description: String(data.id) });
  });

  test('20. Cancel booking', async ({ request }) => {
    // Create one to cancel
    let res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { court_id: 6, start_time: '2026-09-11 09:00:00', end_time: '2026-09-11 10:00:00', type: 'hourly', total_price: 250 },
    });
    const { id } = await res.json();

    res = await request.post(`${API}/bookings/${id}`, {
      headers: { Authorization: `Bearer ${token}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('cancelled');
  });

  test('21. Busy days calendar', async ({ request }) => {
    const res = await request.get(`${API}/bookings/busy-days?court_id=2&month=2026-08`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.busy_days).toBeDefined();
    expect(data.busy_days.length).toBeGreaterThan(0);
  });

  test('22. Blocked slots', async ({ request }) => {
    const res = await request.get(`${API}/blocked-slots?court_id=2`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.blocks).toBeDefined();
  });

  // --- Reviews ---
  test('23. List reviews', async ({ request }) => {
    const res = await request.get(`${API}/reviews?court_id=2`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
    expect(data.avg_rating).toBeDefined();
  });

  // --- Favorites ---
  test('24. List favorites', async ({ request }) => {
    const res = await request.get(`${API}/favorites?user_id=3`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.ids).toBeDefined();
  });

  test('25. Toggle favorite', async ({ request }) => {
    const res = await request.post(`${API}/favorites`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { court_id: 3 },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).favorited).toBeDefined();
  });

  // --- Notifications ---
  test('26. User notifications', async ({ request }) => {
    const res = await request.get(`${API}/user-notifications?user_id=3`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    expect((await res.json()).notifications).toBeDefined();
  });

  // --- Social ---
  test('27. Feed posts', async ({ request }) => {
    const res = await request.get(`${API}/posts`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    expect((await res.json()).records).toBeDefined();
  });

  test('28. Match requests', async ({ request }) => {
    const res = await request.get(`${API}/match-requests`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    expect((await res.json()).requests).toBeDefined();
  });

  // --- Slot Chat ---
  test('29. Slot chat: my groups', async ({ request }) => {
    const res = await request.get(`${API}/slot-chat/my-groups`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.groups).toBeDefined();
    expect(data.groups.length).toBeGreaterThan(0);
    expect(data.groups[0].court_name).toBeDefined();
    expect(data.groups[0].player_count).toBeGreaterThan(0);
  });

  test('30. Slot chat: members', async ({ request }) => {
    const res = await request.get(`${API}/slot-chat/members?court_id=2&date=2026-08-30&time=09:00:00`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.members.length).toBeGreaterThanOrEqual(1);
    // Should include the player and owner
    const types = data.members.map(m => m.member_type);
    expect(types).toContain('player');
    expect(types).toContain('owner');
  });

  test('31. Slot chat: send + read messages', async ({ request }) => {
    // Send
    let res = await request.post(`${API}/slot-chat/messages`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { court_id: 2, date: '2026-08-30', time: '09:00:00', body: 'Playwright test message' },
    });
    expect(res.status()).toBe(201);
    expect((await res.json()).id).toBeDefined();

    // Read
    res = await request.get(`${API}/slot-chat/messages?court_id=2&date=2026-08-30&time=09:00:00`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    const found = data.messages.some(m => m.body === 'Playwright test message');
    expect(found).toBeTruthy();
  });

  test('32. Slot chat: unauthorized access blocked', async ({ request }) => {
    // Player 2 is NOT in the 09:00 slot
    const res2 = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000002', otp: '1234' } });
    const token2 = (await res2.json()).token;

    const res = await request.get(`${API}/slot-chat/messages?court_id=2&date=2026-08-30&time=09:00:00`, {
      headers: { Authorization: `Bearer ${token2}` },
    });
    expect(res.status()).toBe(403);
  });

  // --- Owner ---
  test('33. Owner: list my courts', async ({ request }) => {
    const res = await request.get(`${API}/courts?owner_id=7`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThanOrEqual(3);
  });

  test('34. Owner: list venue bookings', async ({ request }) => {
    const res = await request.get(`${API}/bookings?owner_id=7`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThan(0);
  });

  // --- Pricing & Config ---
  test('35. Pricing rules', async ({ request }) => {
    const res = await request.get(`${API}/pricing-rules?court_id=2`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    expect((await res.json()).rules).toBeDefined();
  });

  // --- Upload ---
  test('36. Upload: valid image succeeds', async ({ request }) => {
    // Create a minimal valid 1x1 PNG in memory
    const pngHeader = Buffer.from([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // 8-bit RGB
      0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
      0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
      0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
      0xAE, 0x42, 0x60, 0x82,
    ]);
    const res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${token}` },
      multipart: {
        image: { name: 'test.png', mimeType: 'image/png', buffer: pngHeader },
      },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.url).toBeDefined();
    expect(data.url).toContain('/uploads/court_');
  });

  test('37. Upload: no file returns 400', async ({ request }) => {
    const res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status()).toBe(400);
  });

  test('38. Upload: invalid file type rejected', async ({ request }) => {
    const textFile = Buffer.from('not an image');
    const res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${token}` },
      multipart: {
        image: { name: 'test.txt', mimeType: 'text/plain', buffer: textFile },
      },
    });
    expect(res.status()).toBe(400);
    const data = await res.json();
    expect(data.message).toContain('Invalid file type');
  });

  test('39. Upload: profile avatar update flow', async ({ request }) => {
    // Create a small valid JPEG
    const jpegHeader = Buffer.from([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
      0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
      0x00, 0x7B, 0x40, 0x1B, 0xFF, 0xD9,
    ]);
    // Step 1: Upload the image
    let res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${token}` },
      multipart: {
        image: { name: 'avatar.jpg', mimeType: 'image/jpeg', buffer: jpegHeader },
      },
    });
    expect(res.status()).toBe(200);
    const { url } = await res.json();
    expect(url).toBeDefined();

    // Step 2: Update profile with the avatar URL
    res = await request.post(`${API}/auth/profile`, {
      headers: { Authorization: `Bearer ${token}`, 'X-HTTP-Method-Override': 'PUT' },
      data: { avatar_url: url },
    });
    expect(res.status()).toBe(200);

    // Step 3: Verify profile has the new avatar
    res = await request.get(`${API}/auth/profile`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status()).toBe(200);
    const profile = await res.json();
    expect(profile.user.avatar_url).toContain('/uploads/court_');
  });

  // --- CORS ---
  test('40. CORS allows Cache-Control header', async ({ request }) => {
    const res = await request.fetch(`${API}/courts`, {
      method: 'OPTIONS',
      headers: { Origin: 'http://localhost:8787', 'Access-Control-Request-Headers': 'Cache-Control' },
    });
    const headers = res.headers();
    const allowHeaders = headers['access-control-allow-headers'] || '';
    expect(allowHeaders.toLowerCase()).toContain('cache-control');
  });
});

// ============================================================
// SECTION 3: Owner Complete Flow Tests
// ============================================================
test.describe('Owner Complete Flow Tests', () => {
  test.describe.configure({ mode: 'serial' });
  let ownerToken;
  let playerToken;
  const ownerId = 7; // phone 9900000010
  let testCourtId;
  let testSubCourtId;
  let testBlockId;
  let testPhotoId;
  let testPricingRuleId;
  let testPlanId;
  let testReviewId;

  test.beforeAll(async ({ request }) => {
    let res = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000010', otp: '1234' } });
    ownerToken = (await res.json()).token;

    res = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000001', otp: '1234' } });
    playerToken = (await res.json()).token;
  });

  // --- Court CRUD ---
  test('O01. Create court', async ({ request }) => {
    const res = await request.post(`${API}/courts`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        name: 'Playwright Test Court',
        type: 'shuttle',
        description: 'Auto-created by Playwright',
        location: 'Test City',
        hourly_rate: 300,
        lat: 13.085,
        lng: 80.21,
        open_time: '06:00:00',
        close_time: '22:00:00',
        amenities: ['Parking', 'Water', 'Lights'],
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();
    testCourtId = data.id;
  });

  test('O02. List owner courts', async ({ request }) => {
    const res = await request.get(`${API}/courts?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThanOrEqual(1);
    const found = data.records.some(c => c.id === testCourtId || c.id === String(testCourtId));
    expect(found).toBeTruthy();
  });

  test('O03. Get court detail', async ({ request }) => {
    const res = await request.get(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court.name).toBe('Playwright Test Court');
    expect(data.court.amenities).toContain('Parking');
  });

  test('O04. Update court', async ({ request }) => {
    const res = await request.post(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'PUT' },
      data: {
        name: 'Playwright Test Court Updated',
        type: 'shuttle',
        description: 'Updated by Playwright',
        location: 'Test City Updated',
        hourly_rate: 350,
        open_time: '07:00:00',
        close_time: '21:00:00',
        amenities: ['Parking', 'Water', 'Lights', 'Changing Room'],
      },
    });
    expect(res.status()).toBe(200);
    // Verify update
    const res2 = await request.get(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const data = await res2.json();
    expect(data.court.name).toBe('Playwright Test Court Updated');
    expect(Number(data.court.hourly_rate)).toBe(350);
  });

  test('O05. Player cannot update owner court', async ({ request }) => {
    const res = await request.post(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'PUT' },
      data: { name: 'Hacked', hourly_rate: 1 },
    });
    expect(res.status()).toBe(403);
  });

  // --- Sub-Courts ---
  test('O06. Create sub-court', async ({ request }) => {
    const res = await request.post(`${API}/sub-courts`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: testCourtId,
        name: 'Court A',
        description: 'First sub-court',
        hourly_rate: 400,
        capacity: 4,
        booking_mode: 'exclusive',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.sub_court).toBeDefined();
    testSubCourtId = data.sub_court.id;
  });

  test('O07. List sub-courts', async ({ request }) => {
    const res = await request.get(`${API}/sub-courts?court_id=${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.sub_courts.length).toBeGreaterThanOrEqual(1);
  });

  test('O08. Update sub-court', async ({ request }) => {
    const res = await request.post(`${API}/sub-courts/${testSubCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'PUT' },
      data: { name: 'Court A Premium', hourly_rate: 500 },
    });
    expect(res.status()).toBe(200);
  });

  test('O09. Player cannot create sub-court', async ({ request }) => {
    const res = await request.post(`${API}/sub-courts`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: testCourtId, name: 'Hacked Court' },
    });
    expect(res.status()).toBe(403);
  });

  // --- Blocked Slots ---
  test('O10. Create blocked slot', async ({ request }) => {
    const res = await request.post(`${API}/blocked-slots`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: testCourtId,
        start_time: '2026-12-25 06:00:00',
        end_time: '2026-12-25 22:00:00',
        reason: 'Christmas Holiday',
        block_kind: 'holiday',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.created).toBe(1);
  });

  test('O11. List blocked slots', async ({ request }) => {
    const res = await request.get(`${API}/blocked-slots?court_id=${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.blocks.length).toBeGreaterThanOrEqual(1);
    // Save the ID for delete test
    testBlockId = data.blocks[0].id;
  });

  test('O12. Delete blocked slot', async ({ request }) => {
    const res = await request.post(`${API}/blocked-slots/${testBlockId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
  });

  // --- Pricing Rules ---
  test('O13. Create pricing rule', async ({ request }) => {
    const res = await request.post(`${API}/pricing-rules`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: testCourtId,
        day_type: 'weekend',
        start_hour: 18,
        end_hour: 21,
        price: 500,
        name: 'Weekend Evening',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.rule).toBeDefined();
    testPricingRuleId = data.rule.id;
  });

  test('O14. List pricing rules', async ({ request }) => {
    const res = await request.get(`${API}/pricing-rules?court_id=${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.rules.length).toBeGreaterThanOrEqual(1);
  });

  test('O15. Delete pricing rule', async ({ request }) => {
    const res = await request.post(`${API}/pricing-rules/${testPricingRuleId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
  });

  // --- Court Photos ---
  test('O16. Add court photo', async ({ request }) => {
    const res = await request.post(`${API}/court-photos`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: testCourtId,
        owner_id: ownerId,
        url: 'https://example.com/test-photo.jpg',
        sort_order: 1,
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();
    testPhotoId = data.id;
  });

  test('O17. List court photos', async ({ request }) => {
    const res = await request.get(`${API}/court-photos?court_id=${testCourtId}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.photos.length).toBeGreaterThanOrEqual(1);
    expect(data.photos[0].url).toContain('test-photo');
  });

  test('O18. Delete court photo', async ({ request }) => {
    const res = await request.post(`${API}/court-photos/${testPhotoId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
      data: { owner_id: ownerId },
    });
    expect(res.status()).toBe(200);
  });

  test('O19. Non-owner cannot add photo', async ({ request }) => {
    const res = await request.post(`${API}/court-photos`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: testCourtId, owner_id: 1, url: 'https://example.com/hack.jpg' },
    });
    expect(res.status()).toBe(403);
  });

  // --- Plans ---
  test('O20. Create plan', async ({ request }) => {
    const res = await request.post(`${API}/plans`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: testCourtId,
        name: 'Monthly Pass',
        duration_days: 30,
        price: 2000,
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.message).toContain('created');
  });

  test('O21. List plans', async ({ request }) => {
    const res = await request.get(`${API}/plans?court_id=${testCourtId}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThanOrEqual(1);
    testPlanId = data.records[0].id;
  });

  test('O22. Delete plan', async ({ request }) => {
    if (!testPlanId) { test.skip(); return; }
    const res = await request.post(`${API}/plans/${testPlanId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
  });

  // --- Owner Bookings View ---
  test('O23. Owner list venue bookings', async ({ request }) => {
    const res = await request.get(`${API}/bookings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
  });

  // --- Reviews & Replies ---
  test('O24. Owner view reviews for their courts', async ({ request }) => {
    const res = await request.get(`${API}/reviews?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
    // Store a review ID for reply test if available
    if (data.records.length > 0) {
      testReviewId = data.records[0].id;
    }
  });

  test('O25. Owner reply to review', async ({ request }) => {
    if (!testReviewId) {
      test.skip();
      return;
    }
    const res = await request.post(`${API}/reviews/${testReviewId}/reply`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'PUT' },
      data: { reply: 'Thank you for your feedback! — Playwright test' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('Reply saved');
  });

  // --- Earnings ---
  test('O26. Earnings summary', async ({ request }) => {
    const res = await request.get(`${API}/earnings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.summary).toBeDefined();
    expect(data.summary.total_earned).toBeDefined();
    expect(data.summary.this_week).toBeDefined();
    expect(data.summary.this_month).toBeDefined();
    expect(data.transactions).toBeDefined();
  });

  test('O27. Earnings ledger', async ({ request }) => {
    const res = await request.get(`${API}/earnings/ledger?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.entries).toBeDefined();
    expect(data.totals).toBeDefined();
  });

  test('O28. Earnings venue breakdown', async ({ request }) => {
    // Use one of owner's existing courts (court_id=2 is owned by user 7)
    const res = await request.get(`${API}/earnings/venue?court_id=2&owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.summary).toBeDefined();
    expect(data.monthly).toBeDefined();
    expect(data.transactions).toBeDefined();
  });

  test('O29. Player cannot access earnings', async ({ request }) => {
    const res = await request.get(`${API}/earnings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  // --- Analytics ---
  test('O30. Analytics dashboard', async ({ request }) => {
    const res = await request.get(`${API}/analytics?period=30`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.revenue_by_day).toBeDefined();
    expect(data.heatmap).toBeDefined();
    expect(data.top_courts).toBeDefined();
    expect(data.summary).toBeDefined();
  });

  test('O31. Player cannot access analytics', async ({ request }) => {
    const res = await request.get(`${API}/analytics?period=30`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  // --- Staff Management ---
  test('O32. List staff', async ({ request }) => {
    // Use existing owner court (court_id=2)
    const res = await request.get(`${API}/court-staff?court_id=2`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.staff).toBeDefined();
  });

  test('O33. Add staff member', async ({ request }) => {
    const res = await request.post(`${API}/court-staff`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: 2, // existing owner court
        phone: '9900000002', // Priya Sharma
        role: 'manager',
      },
    });
    // Could be 201 (created) or 409 (already exists)
    expect([200, 201, 409]).toContain(res.status());
  });

  test('O34. Player cannot add staff', async ({ request }) => {
    const res = await request.post(`${API}/court-staff`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: 2, phone: '9900000003', role: 'viewer' },
    });
    expect(res.status()).toBe(403);
  });

  // --- Subscription Members ---
  test('O35. View subscription members', async ({ request }) => {
    const res = await request.get(`${API}/subscriptions/members?court_id=2`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.members).toBeDefined();
  });

  // --- Regulars ---
  test('O36. Court regulars', async ({ request }) => {
    const res = await request.get(`${API}/courts/2/regulars`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.players).toBeDefined();
  });

  // --- Cleanup: Delete test sub-court & court ---
  test('O37. Delete sub-court', async ({ request }) => {
    if (!testSubCourtId) { test.skip(); return; }
    const res = await request.post(`${API}/sub-courts/${testSubCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
  });

  test('O38. Delete court', async ({ request }) => {
    if (!testCourtId) { test.skip(); return; }
    const res = await request.post(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    // Verify it's gone
    const res2 = await request.get(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res2.status()).toBe(404);
  });

  test('O39. Player cannot delete owner court', async ({ request }) => {
    // Try to delete an existing owner court as player
    const res = await request.post(`${API}/courts/2`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(403);
  });

  // --- Staff Remove ---
  test('O40. Remove staff member', async ({ request }) => {
    // List staff first to get the ID
    let res = await request.get(`${API}/court-staff?court_id=2`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const data = await res.json();
    if (!data.staff || data.staff.length === 0) { test.skip(); return; }
    const staffId = data.staff[data.staff.length - 1].id; // remove last added
    res = await request.post(`${API}/court-staff/${staffId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('removed');
  });

  // --- Calendar (Owner Day/Week View) ---
  test('O41. Calendar day view', async ({ request }) => {
    const res = await request.get(`${API}/courts/2/calendar?date=2026-08-30&view=day`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court).toBeDefined();
    expect(data.court.name).toContain('Smash');
    expect(data.view).toBe('day');
    expect(data.bookings).toBeDefined();
    expect(data.blocked_slots).toBeDefined();
    expect(data.sub_courts).toBeDefined();
  });

  test('O42. Calendar week view', async ({ request }) => {
    const res = await request.get(`${API}/courts/2/calendar?date=2026-08-30&view=week`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.view).toBe('week');
    expect(data.dates).toBeDefined();
    expect(data.dates.length).toBe(7);
    expect(data.bookings).toBeDefined();
  });

  test('O43. Player cannot access calendar', async ({ request }) => {
    const res = await request.get(`${API}/courts/2/calendar?date=2026-08-30`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  // --- Earnings Export (CSV) ---
  test('O44. Earnings CSV export', async ({ request }) => {
    const res = await request.get(`${API}/earnings/export?court_id=2&owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const contentType = res.headers()['content-type'] || '';
    expect(contentType).toContain('text/csv');
    const body = await res.text();
    expect(body).toContain('Date,Space,Player');
  });

  // --- Pricing Calculate ---
  test('O45. Pricing calculate for slot', async ({ request }) => {
    const res = await request.get(`${API}/pricing-rules/calculate?court_id=2&date=2026-09-06&hour=18`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.effective_price).toBeDefined();
    expect(data.base_price).toBeDefined();
  });

  test('O45b. Pricing calculate-day', async ({ request }) => {
    const res = await request.get(`${API}/pricing-rules/calculate-day?court_id=2&date=2026-09-06`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.prices).toBeDefined();
    expect(Object.keys(data.prices).length).toBe(24);
  });

  // --- Owner Walk-in Booking ---
  test('O46. Owner creates walk-in booking', async ({ request }) => {
    const d = 10 + Math.floor(Math.random() * 20);
    const h = 6 + Math.floor(Math.random() * 12);
    const res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: 2,
        start_time: `2026-11-${String(d).padStart(2,'0')} ${String(h).padStart(2,'0')}:00:00`,
        end_time: `2026-11-${String(d).padStart(2,'0')} ${String(h+1).padStart(2,'0')}:00:00`,
        type: 'hourly',
        total_price: 400,
        guest_name: 'Walk-in Player',
        guest_phone: '9999999999',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();
  });

  // --- Owner Cancels Booking ---
  test('O47. Owner cancels player booking on own court', async ({ request }) => {
    // Create a booking as player on owner's court
    let res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        court_id: 2,
        start_time: '2026-11-05 07:00:00',
        end_time: '2026-11-05 08:00:00',
        type: 'hourly',
        total_price: 400,
      },
    });
    const { id } = await res.json();

    // Owner cancels it
    res = await request.post(`${API}/bookings/${id}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('cancelled');
  });

  // --- Booking Detail ---
  test('O48. Owner views booking detail', async ({ request }) => {
    // Get an existing booking
    let res = await request.get(`${API}/bookings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const bookings = (await res.json()).records;
    if (!bookings || bookings.length === 0) { test.skip(); return; }
    const bookingId = bookings[0].id;

    res = await request.get(`${API}/bookings/${bookingId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.booking).toBeDefined();
    expect(data.booking.court_name || data.booking.court_id).toBeDefined();
  });

  // --- Booking-Scoped Messages ---
  test('O49. Owner messages thread', async ({ request }) => {
    const res = await request.get(`${API}/messages/threads`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.threads).toBeDefined();
  });

  // --- Blocked Slots with Hours Array ---
  test('O50. Create blocked slots (hours array)', async ({ request }) => {
    const res = await request.post(`${API}/blocked-slots`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: 2,
        date: '2026-12-31',
        hours: [6, 7, 8],
        reason: 'New Year Maintenance',
        block_kind: 'maintenance',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.created).toBe(3); // 3 hour-long blocks

    // Cleanup: delete them
    const listRes = await request.get(`${API}/blocked-slots?court_id=2&date=2026-12-31`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const blocks = (await listRes.json()).blocks;
    for (const b of blocks) {
      await request.post(`${API}/blocked-slots/${b.id}`, {
        headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
      });
    }
  });

  // --- Sub-Court Pricing Rule ---
  test('O51. Pricing rule for sub-court', async ({ request }) => {
    // Get sub-courts for court 2
    let res = await request.get(`${API}/sub-courts?court_id=2`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const subCourts = (await res.json()).sub_courts;
    if (!subCourts || subCourts.length === 0) { test.skip(); return; }
    const scId = subCourts[0].id;

    // Create rule for sub-court
    res = await request.post(`${API}/pricing-rules`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: 2,
        sub_court_id: scId,
        day_type: 'weekday',
        start_hour: 9,
        end_hour: 17,
        price: 350,
        name: 'Weekday Office Hours',
      },
    });
    expect(res.status()).toBe(201);
    const ruleId = (await res.json()).rule.id;

    // List rules for sub-court
    res = await request.get(`${API}/pricing-rules?court_id=2&sub_court_id=${scId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).rules.length).toBeGreaterThanOrEqual(1);

    // Cleanup
    await request.post(`${API}/pricing-rules/${ruleId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
  });

  // --- Court Photo Upload + Add Flow ---
  test('O52. Upload image then add as court photo', async ({ request }) => {
    const pngData = Buffer.from([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
      0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
      0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
      0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
      0xAE, 0x42, 0x60, 0x82,
    ]);
    // Step 1: Upload
    let res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      multipart: { image: { name: 'court.png', mimeType: 'image/png', buffer: pngData } },
    });
    expect(res.status()).toBe(200);
    const { url } = await res.json();

    // Step 2: Add as court photo
    res = await request.post(`${API}/court-photos`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: { court_id: 2, owner_id: ownerId, url, sort_order: 0 },
    });
    expect(res.status()).toBe(201);
    const photoId = (await res.json()).id;

    // Step 3: Verify it appears
    res = await request.get(`${API}/court-photos?court_id=2`);
    const photos = (await res.json()).photos;
    const found = photos.some(p => String(p.id) === String(photoId));
    expect(found).toBeTruthy();

    // Cleanup
    await request.post(`${API}/court-photos/${photoId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
      data: { owner_id: ownerId },
    });
  });

  // --- Staff My-Courts (staff perspective) ---
  test('O53. Staff my-courts view', async ({ request }) => {
    // First add player as staff
    await request.post(`${API}/court-staff`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: { court_id: 2, phone: '9900000003', role: 'manager' },
    });

    // Get token for that player
    const r = await request.post(`${API}/auth/verify-otp`, { data: { phone: '9900000003', otp: '1234' } });
    const staffToken = (await r.json()).token;

    // Check my-courts as staff
    const res = await request.get(`${API}/court-staff/my-courts`, {
      headers: { Authorization: `Bearer ${staffToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.courts).toBeDefined();
    expect(data.courts.length).toBeGreaterThanOrEqual(1);

    // Cleanup: remove staff
    const listRes = await request.get(`${API}/court-staff?court_id=2`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const staffList = (await listRes.json()).staff;
    const entry = staffList.find(s => s.phone === '9900000003');
    if (entry) {
      await request.post(`${API}/court-staff/${entry.id}`, {
        headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
      });
    }
  });
});
