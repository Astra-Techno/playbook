const { test, expect } = require('@playwright/test');

const BASE = process.env.E2E_BASE_URL || 'https://www.kocourt.com';
const API = process.env.E2E_API_BASE_URL || 'https://www.kocourt.com/api';

// ── Live server phones ──────────────────────────────────────────────────────
// User 1 (Mathavan, admin, owns all courts): 9994439081
// Test player: 9000000099 (created on-the-fly via demo OTP)
const ADMIN_PHONE = '9994439081';
const PLAYER_PHONE = '9000000099';
const PLAYER2_PHONE = '9000000098';

// Known court IDs on live server (all owned by user 1)
const COURT_HAP = 1;        // HAP Sports Trust (shuttle, has sub-courts)
const COURT_MJ = 2;         // MJ Sports (shuttle)
const COURT_AJ_CRICKET = 5; // AJ Cricket
const COURT_AJ_BOXING = 6;  // AJ boxing

// Helper: get auth token via demo OTP (creates user if new)
async function getToken(request, phone, name) {
  await request.post(`${API}/auth/send-otp`, { data: { phone } });
  const res = await request.post(`${API}/auth/verify-otp`, { data: { phone, otp: '1234' } });
  const data = await res.json();
  if (data.new_user && name) {
    // verify-otp with name included completes registration
    const regRes = await request.post(`${API}/auth/verify-otp`, {
      data: { phone, otp: '1234', name },
    });
    const regData = await regRes.json();
    return { token: regData.token, user: regData.user };
  }
  return { token: data.token, user: data.user };
}

// Helper: generate a future datetime string that won't collide
function futureSlot(monthsAhead = 6, hourOffset = 0) {
  const d = new Date();
  d.setMonth(d.getMonth() + monthsAhead);
  d.setDate(Math.floor(Math.random() * 25) + 1);
  d.setHours(6 + Math.floor(Math.random() * 12) + hourOffset, 0, 0, 0);
  return d.toISOString().slice(0, 19).replace('T', ' ');
}

function futureSlotPair(monthsAhead = 6) {
  const d = new Date();
  d.setMonth(d.getMonth() + monthsAhead);
  d.setDate(Math.floor(Math.random() * 25) + 1);
  const h = 6 + Math.floor(Math.random() * 12);
  d.setHours(h, 0, 0, 0);
  const start = d.toISOString().slice(0, 19).replace('T', ' ');
  d.setHours(h + 1);
  const end = d.toISOString().slice(0, 19).replace('T', ' ');
  return { start, end };
}

// ============================================================
// SECTION 1: Vue Web UI Tests
// ============================================================
test.describe('Vue Web UI Tests', () => {
  test('01. Homepage loads', async ({ page }) => {
    await page.goto(BASE);
    await page.waitForLoadState('networkidle');
    const title = await page.title();
    expect(title).toBeTruthy();
  });

  test('02. Home shows court listings', async ({ page }) => {
    await page.goto(BASE);
    await page.waitForLoadState('networkidle');
    // Wait for Vue to render content
    await page.waitForTimeout(2000);
    const body = await page.textContent('body');
    expect(body.length).toBeGreaterThan(100);
  });

  test('03. Court details page loads', async ({ page }) => {
    await page.goto(`${BASE}/courts/${COURT_HAP}`);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    const body = await page.textContent('body');
    expect(body).toContain('HAP Sports Trust');
  });

  test('04. Login page renders', async ({ page }) => {
    await page.goto(`${BASE}/login`);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    const body = await page.textContent('body');
    // Should have phone input or login-related content
    expect(body.length).toBeGreaterThan(50);
  });

  test('05. Feed page loads', async ({ page }) => {
    await page.goto(`${BASE}/feed`);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    const body = await page.textContent('body');
    expect(body.length).toBeGreaterThan(50);
  });

  test('06. Find courts page loads', async ({ page }) => {
    await page.goto(`${BASE}/find-courts`);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    const body = await page.textContent('body');
    expect(body.length).toBeGreaterThan(50);
  });

  test('07. Terms page loads', async ({ page }) => {
    await page.goto(`${BASE}/terms`);
    await page.waitForLoadState('networkidle');
    const body = await page.textContent('body');
    expect(body).toContain('Terms');
  });

  test('08. Privacy page loads', async ({ page }) => {
    await page.goto(`${BASE}/privacy`);
    await page.waitForLoadState('networkidle');
    const body = await page.textContent('body');
    expect(body).toContain('Privacy');
  });

  test('09. Download page loads', async ({ page }) => {
    await page.goto(`${BASE}/download`);
    await page.waitForLoadState('networkidle');
    const body = await page.textContent('body');
    expect(body).toContain('KoCourt');
  });

  test('10. Different routes show different content', async ({ page }) => {
    await page.goto(`${BASE}/login`);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    const loginShot = await page.screenshot();

    await page.goto(BASE);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    const homeShot = await page.screenshot();

    expect(Buffer.compare(loginShot, homeShot) !== 0).toBeTruthy();
  });
});

// ============================================================
// SECTION 2: API Integration Tests
// ============================================================
test.describe('API Integration Tests', () => {
  let adminToken;
  let playerToken;
  let playerId;

  test.beforeAll(async ({ request }) => {
    // Admin/owner token (user 1 - Mathavan)
    const admin = await getToken(request, ADMIN_PHONE);
    adminToken = admin.token;

    // Player token (creates user if needed)
    const player = await getToken(request, PLAYER_PHONE, 'E2E Player');
    playerToken = player.token;
    playerId = player.user?.id;
  });

  // --- Auth ---
  test('11. Send OTP', async ({ request }) => {
    const res = await request.post(`${API}/auth/send-otp`, { data: { phone: ADMIN_PHONE } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.message).toBe('OTP sent');
  });

  test('12. Verify OTP returns token + user', async ({ request }) => {
    const res = await request.post(`${API}/auth/verify-otp`, { data: { phone: ADMIN_PHONE, otp: '1234' } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.token).toBeDefined();
    expect(data.user.name).toBe('Mathavan');
  });

  test('13. Get profile', async ({ request }) => {
    const res = await request.get(`${API}/auth/profile`, { headers: { Authorization: `Bearer ${adminToken}` } });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.user.name).toBe('Mathavan');
    expect(data.user.phone).toBe(ADMIN_PHONE);
  });

  test('14. Unauthenticated request is rejected', async ({ request }) => {
    const res = await request.get(`${API}/auth/profile`);
    expect(res.status()).toBe(401);
  });

  // --- Courts ---
  test('15. List courts', async ({ request }) => {
    const res = await request.get(`${API}/courts`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThanOrEqual(5);
  });

  test('16. Court detail', async ({ request }) => {
    const res = await request.get(`${API}/courts/${COURT_HAP}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court.name).toContain('HAP Sports Trust');
    expect(data.court.amenities).toContain('Parking');
  });

  test('17. Sub-courts', async ({ request }) => {
    const res = await request.get(`${API}/sub-courts?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.sub_courts.length).toBeGreaterThanOrEqual(2);
  });

  // --- Bookings ---
  test('18. Create and cancel booking', async ({ request }) => {
    const { start, end } = futureSlotPair(8);
    const res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${adminToken}` },
      data: { court_id: COURT_AJ_CRICKET, start_time: start, end_time: end, type: 'hourly', total_price: 500 },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();

    // Cancel it
    const cancelRes = await request.post(`${API}/bookings/${data.id}`, {
      headers: { Authorization: `Bearer ${adminToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(cancelRes.status()).toBe(200);
    expect((await cancelRes.json()).message).toContain('cancelled');
  });

  test('19. Busy days calendar', async ({ request }) => {
    const now = new Date();
    const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const res = await request.get(`${API}/bookings/busy-days?court_id=${COURT_HAP}&month=${month}`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.busy_days).toBeDefined();
  });

  test('20. Blocked slots', async ({ request }) => {
    const res = await request.get(`${API}/blocked-slots?court_id=${COURT_HAP}`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.blocks).toBeDefined();
  });

  // --- Reviews ---
  test('21. List reviews', async ({ request }) => {
    const res = await request.get(`${API}/reviews?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
    expect(data.avg_rating).toBeDefined();
  });

  // --- Favorites ---
  test('22. Toggle favorite', async ({ request }) => {
    const res = await request.post(`${API}/favorites`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: COURT_AJ_CRICKET },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).favorited).toBeDefined();
  });

  test('23. List favorites', async ({ request }) => {
    if (!playerId) { test.skip(); return; }
    const res = await request.get(`${API}/favorites?user_id=${playerId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).ids).toBeDefined();
  });

  // --- Notifications ---
  test('24. User notifications', async ({ request }) => {
    const res = await request.get(`${API}/notifications/list`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).notifications).toBeDefined();
  });

  // --- Social ---
  test('25. Feed posts', async ({ request }) => {
    const res = await request.get(`${API}/posts`, { headers: { Authorization: `Bearer ${adminToken}` } });
    expect(res.status()).toBe(200);
    expect((await res.json()).records).toBeDefined();
  });

  test('26. Match requests', async ({ request }) => {
    const res = await request.get(`${API}/match-requests`, { headers: { Authorization: `Bearer ${adminToken}` } });
    expect(res.status()).toBe(200);
    expect((await res.json()).requests).toBeDefined();
  });

  // --- Upload ---
  test('27. Upload: valid image succeeds', async ({ request }) => {
    const pngHeader = Buffer.from([
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
    const res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${adminToken}` },
      multipart: { image: { name: 'test.png', mimeType: 'image/png', buffer: pngHeader } },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.url).toBeDefined();
    expect(data.url).toContain('/uploads/');
  });

  test('28. Upload: no file returns 400', async ({ request }) => {
    const res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    expect(res.status()).toBe(400);
  });

  test('29. Upload: invalid file type rejected', async ({ request }) => {
    const textFile = Buffer.from('not an image');
    const res = await request.post(`${API}/upload`, {
      headers: { Authorization: `Bearer ${adminToken}` },
      multipart: { image: { name: 'test.txt', mimeType: 'text/plain', buffer: textFile } },
    });
    expect(res.status()).toBe(400);
    const data = await res.json();
    expect(data.message).toContain('Invalid file type');
  });

  // --- CORS ---
  test('30. CORS allows Cache-Control header', async ({ request }) => {
    const res = await request.fetch(`${API}/courts`, {
      method: 'OPTIONS',
      headers: { Origin: 'https://www.kocourt.com', 'Access-Control-Request-Headers': 'Cache-Control' },
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
  let ownerId;
  let testCourtId;
  let testSubCourtId;
  let testBlockId;
  let testPhotoId;
  let testPricingRuleId;
  let testPlanId;

  test.beforeAll(async ({ request }) => {
    const owner = await getToken(request, ADMIN_PHONE);
    ownerToken = owner.token;
    ownerId = owner.user.id;

    const player = await getToken(request, PLAYER_PHONE, 'E2E Player');
    playerToken = player.token;
  });

  // --- Court CRUD ---
  test('O01. Create court', async ({ request }) => {
    const res = await request.post(`${API}/courts`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        name: 'E2E Test Court',
        type: 'shuttle',
        description: 'Auto-created by E2E tests',
        location: 'Test City',
        hourly_rate: 300,
        lat: 9.499,
        lng: 77.817,
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

  test('O02. List owner courts includes new court', async ({ request }) => {
    const res = await request.get(`${API}/courts?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThanOrEqual(1);
    const found = data.records.some(c => Number(c.id) === Number(testCourtId));
    expect(found).toBeTruthy();
  });

  test('O03. Get court detail', async ({ request }) => {
    const res = await request.get(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court.name).toBe('E2E Test Court');
    expect(data.court.amenities).toContain('Parking');
  });

  test('O04. Update court', async ({ request }) => {
    const res = await request.post(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'PUT' },
      data: {
        name: 'E2E Test Court Updated',
        type: 'shuttle',
        description: 'Updated by E2E',
        location: 'Test City Updated',
        hourly_rate: 350,
        open_time: '07:00:00',
        close_time: '21:00:00',
        amenities: ['Parking', 'Water', 'Lights', 'Changing Room'],
      },
    });
    expect(res.status()).toBe(200);
    const res2 = await request.get(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const data = await res2.json();
    expect(data.court.name).toBe('E2E Test Court Updated');
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
        start_time: '2028-12-25 06:00:00',
        end_time: '2028-12-25 22:00:00',
        reason: 'E2E Holiday Test',
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
        url: 'https://example.com/e2e-test-photo.jpg',
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
        name: 'E2E Monthly Pass',
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

  // --- Owner Bookings ---
  test('O23. Owner list venue bookings', async ({ request }) => {
    const res = await request.get(`${API}/bookings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
  });

  // --- Reviews ---
  test('O24. Owner view reviews for their courts', async ({ request }) => {
    const res = await request.get(`${API}/reviews?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).records).toBeDefined();
  });

  // --- Earnings ---
  test('O25. Earnings summary', async ({ request }) => {
    const res = await request.get(`${API}/earnings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.summary).toBeDefined();
    expect(data.summary.total_earned).toBeDefined();
  });

  test('O26. Earnings ledger', async ({ request }) => {
    const res = await request.get(`${API}/earnings/ledger?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.entries).toBeDefined();
    expect(data.totals).toBeDefined();
  });

  test('O27. Player cannot access earnings', async ({ request }) => {
    const res = await request.get(`${API}/earnings?owner_id=${ownerId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  // --- Analytics ---
  test('O28. Analytics dashboard', async ({ request }) => {
    const res = await request.get(`${API}/analytics?period=30`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.summary).toBeDefined();
  });

  test('O29. Player analytics returns empty (no courts)', async ({ request }) => {
    const res = await request.get(`${API}/analytics?period=30`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.summary).toBeDefined();
  });

  // --- Staff Management ---
  test('O30. List staff', async ({ request }) => {
    const res = await request.get(`${API}/court-staff?court_id=${COURT_HAP}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).staff).toBeDefined();
  });

  test('O31. Player cannot add staff', async ({ request }) => {
    const res = await request.post(`${API}/court-staff`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: COURT_HAP, phone: PLAYER2_PHONE, role: 'viewer' },
    });
    expect(res.status()).toBe(403);
  });

  // --- Subscription Members ---
  test('O32. View subscription members', async ({ request }) => {
    const res = await request.get(`${API}/subscriptions/members?court_id=${COURT_HAP}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).members).toBeDefined();
  });

  // --- Regulars ---
  test('O33. Court regulars', async ({ request }) => {
    const res = await request.get(`${API}/courts/${COURT_HAP}/regulars`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).players).toBeDefined();
  });

  // --- Calendar ---
  test('O34. Calendar day view', async ({ request }) => {
    const today = new Date().toISOString().slice(0, 10);
    const res = await request.get(`${API}/courts/${COURT_HAP}/calendar?date=${today}&view=day`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court).toBeDefined();
    expect(data.view).toBe('day');
    expect(data.bookings).toBeDefined();
  });

  test('O35. Calendar week view', async ({ request }) => {
    const today = new Date().toISOString().slice(0, 10);
    const res = await request.get(`${API}/courts/${COURT_HAP}/calendar?date=${today}&view=week`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.view).toBe('week');
    expect(data.dates.length).toBe(7);
  });

  test('O36. Player cannot access calendar', async ({ request }) => {
    const today = new Date().toISOString().slice(0, 10);
    const res = await request.get(`${API}/courts/${COURT_HAP}/calendar?date=${today}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  // --- Pricing Calculate ---
  test('O37. Pricing calculate for slot', async ({ request }) => {
    const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const res = await request.get(`${API}/pricing-rules/calculate?court_id=${COURT_HAP}&date=${tomorrow}&hour=10`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.effective_price).toBeDefined();
    expect(data.base_price).toBeDefined();
  });

  test('O38. Pricing calculate-day', async ({ request }) => {
    const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const res = await request.get(`${API}/pricing-rules/calculate-day?court_id=${COURT_HAP}&date=${tomorrow}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.prices).toBeDefined();
    expect(Object.keys(data.prices).length).toBe(24);
  });

  // --- Blocked Slots with Hours Array ---
  test('O39. Create blocked slots (hours array)', async ({ request }) => {
    const res = await request.post(`${API}/blocked-slots`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: testCourtId,
        date: '2028-12-31',
        hours: [6, 7, 8],
        reason: 'E2E Maintenance',
        block_kind: 'maintenance',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.created).toBe(3);

    // Cleanup
    const listRes = await request.get(`${API}/blocked-slots?court_id=${testCourtId}&date=2028-12-31`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const blocks = (await listRes.json()).blocks;
    for (const b of blocks) {
      await request.post(`${API}/blocked-slots/${b.id}`, {
        headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
      });
    }
  });

  // --- Owner Walk-in Booking ---
  test('O40. Owner creates walk-in booking', async ({ request }) => {
    const { start, end } = futureSlotPair(9);
    const res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
      data: {
        court_id: COURT_MJ,
        start_time: start,
        end_time: end,
        type: 'hourly',
        total_price: 400,
        guest_name: 'Walk-in Player',
        guest_phone: '9999999999',
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();

    // Cleanup
    await request.post(`${API}/bookings/${data.id}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
  });

  // --- Cleanup: Delete test sub-court & court ---
  test('O41. Delete sub-court', async ({ request }) => {
    if (!testSubCourtId) { test.skip(); return; }
    const res = await request.post(`${API}/sub-courts/${testSubCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
  });

  test('O42. Delete court', async ({ request }) => {
    if (!testCourtId) { test.skip(); return; }
    const res = await request.post(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    const res2 = await request.get(`${API}/courts/${testCourtId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    expect(res2.status()).toBe(404);
  });

  test('O43. Player cannot delete owner court', async ({ request }) => {
    const res = await request.post(`${API}/courts/${COURT_HAP}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(403);
  });
});

// ============================================================
// SECTION 4: Player Complete Flow Tests
// ============================================================
test.describe('Player Complete Flow Tests', () => {
  test.describe.configure({ mode: 'serial' });

  let playerToken;
  let player2Token;
  let ownerToken;
  let playerId;
  let player2Id;
  let testBookingId;
  let testPostId;
  let testMatchId;

  test.beforeAll(async ({ request }) => {
    const player = await getToken(request, PLAYER_PHONE, 'E2E Player');
    playerToken = player.token;
    playerId = player.user?.id;

    const player2 = await getToken(request, PLAYER2_PHONE, 'E2E Player2');
    player2Token = player2.token;
    player2Id = player2.user?.id;

    const owner = await getToken(request, ADMIN_PHONE);
    ownerToken = owner.token;
  });

  // ===================== AUTH & PROFILE =====================
  test('P01. Update profile', async ({ request }) => {
    const res = await request.post(`${API}/auth/profile`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'PUT' },
      data: {
        name: 'E2E Player',
        bio: 'Badminton enthusiast',
        skill_level: 'intermediate',
        sport_preferences: ['badminton', 'tennis'],
      },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.user.bio).toBe('Badminton enthusiast');
    expect(data.user.skill_level).toBe('intermediate');
  });

  test('P02. Verify profile reflects updates', async ({ request }) => {
    const res = await request.get(`${API}/auth/profile`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.user.bio).toBe('Badminton enthusiast');
  });

  test('P03. Save FCM token', async ({ request }) => {
    const res = await request.post(`${API}/auth/fcm-token`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { token: 'fcm_e2e_test_token_12345' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).success).toBe(true);
  });

  test('P04. FCM token without value returns 400', async ({ request }) => {
    const res = await request.post(`${API}/auth/fcm-token`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { token: '' },
    });
    expect(res.status()).toBe(400);
  });

  // ===================== COURT DISCOVERY =====================
  test('P05. Search courts by type filter', async ({ request }) => {
    const res = await request.get(`${API}/courts?type=shuttle`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
    if (data.records.length > 0) {
      expect(data.records[0].type).toBe('shuttle');
    }
  });

  test('P06. Search courts by GPS', async ({ request }) => {
    const res = await request.get(`${API}/courts?lat=9.499&lng=77.817&radius=50`);
    expect(res.status()).toBe(200);
    expect((await res.json()).records).toBeDefined();
  });

  test('P07. Court detail includes full info', async ({ request }) => {
    const res = await request.get(`${API}/courts/${COURT_HAP}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.court.name).toBeDefined();
    expect(data.court.hourly_rate).toBeDefined();
    expect(data.court.open_time).toBeDefined();
    expect(data.court.close_time).toBeDefined();
    expect(data.court.amenities).toBeDefined();
    expect(data.court.lat).toBeDefined();
  });

  test('P08. Court photos gallery', async ({ request }) => {
    const res = await request.get(`${API}/court-photos?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    expect((await res.json()).photos).toBeDefined();
  });

  test('P09. Non-existent court returns 404', async ({ request }) => {
    const res = await request.get(`${API}/courts/99999`);
    expect(res.status()).toBe(404);
  });

  test('P10. Sub-courts for a court', async ({ request }) => {
    const res = await request.get(`${API}/sub-courts?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.sub_courts).toBeDefined();
    expect(data.sub_courts.length).toBeGreaterThanOrEqual(2);
  });

  // ===================== PRICING & AVAILABILITY =====================
  test('P11. Calculate slot price', async ({ request }) => {
    const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const res = await request.get(`${API}/pricing-rules/calculate?court_id=${COURT_HAP}&date=${tomorrow}&hour=10`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.effective_price).toBeDefined();
    expect(data.base_price).toBeDefined();
  });

  test('P12. Calculate full day prices', async ({ request }) => {
    const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const res = await request.get(`${API}/pricing-rules/calculate-day?court_id=${COURT_HAP}&date=${tomorrow}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.prices).toBeDefined();
    expect(Object.keys(data.prices).length).toBe(24);
  });

  test('P13. View blocked slots', async ({ request }) => {
    const res = await request.get(`${API}/blocked-slots?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    expect((await res.json()).blocks).toBeDefined();
  });

  test('P14. Busy days calendar', async ({ request }) => {
    const now = new Date();
    const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const res = await request.get(`${API}/bookings/busy-days?court_id=${COURT_HAP}&month=${month}`);
    expect(res.status()).toBe(200);
    expect((await res.json()).busy_days).toBeDefined();
  });

  // ===================== BOOKINGS =====================
  test('P15. Create booking', async ({ request }) => {
    const { start, end } = futureSlotPair(7);
    const res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        court_id: COURT_MJ,
        start_time: start,
        end_time: end,
        type: 'hourly',
        total_price: 500,
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();
    testBookingId = data.id;
  });

  test('P16. View booking detail', async ({ request }) => {
    const res = await request.get(`${API}/bookings/${testBookingId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.booking).toBeDefined();
    expect(data.booking.status).toBe('confirmed');
  });

  test('P17. List my bookings', async ({ request }) => {
    if (!playerId) { test.skip(); return; }
    const res = await request.get(`${API}/bookings?user_id=${playerId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records.length).toBeGreaterThan(0);
  });

  test('P18. Create booking with sub-court', async ({ request }) => {
    let res = await request.get(`${API}/sub-courts?court_id=${COURT_HAP}`);
    const subs = (await res.json()).sub_courts;
    if (!subs || subs.length === 0) { test.skip(); return; }

    const { start, end } = futureSlotPair(10);
    res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        court_id: COURT_HAP,
        sub_court_id: subs[0].id,
        start_time: start,
        end_time: end,
        type: 'hourly',
        total_price: 600,
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();

    // Cleanup
    await request.post(`${API}/bookings/${data.id}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
  });

  test('P19. Cancel booking', async ({ request }) => {
    const res = await request.post(`${API}/bookings/${testBookingId}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('cancelled');
  });

  test('P20. Cancel already-cancelled booking fails', async ({ request }) => {
    const res = await request.post(`${API}/bookings/${testBookingId}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect([400, 404]).toContain(res.status());
  });

  // ===================== BOOKING PLAYERS (Invite) =====================
  test('P21. Create booking for invite tests', async ({ request }) => {
    const { start, end } = futureSlotPair(11);
    const res = await request.post(`${API}/bookings`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        court_id: COURT_AJ_CRICKET,
        start_time: start,
        end_time: end,
        type: 'hourly',
        total_price: 500,
      },
    });
    expect(res.status()).toBe(201);
    testBookingId = (await res.json()).id;
  });

  test('P22. Invite players to booking', async ({ request }) => {
    if (!player2Id) { test.skip(); return; }
    const res = await request.post(`${API}/booking-players`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { booking_id: testBookingId, user_ids: [player2Id] },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).added).toBeGreaterThanOrEqual(1);
  });

  test('P23. List booking players', async ({ request }) => {
    const res = await request.get(`${API}/booking-players?booking_id=${testBookingId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).players).toBeDefined();
  });

  // ===================== REVIEWS =====================
  test('P24. List reviews for court', async ({ request }) => {
    const res = await request.get(`${API}/reviews?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
    expect(data.avg_rating).toBeDefined();
  });

  // ===================== FAVORITES =====================
  test('P25. Toggle favorite on', async ({ request }) => {
    const res = await request.post(`${API}/favorites`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: COURT_AJ_BOXING },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).favorited).toBeDefined();
  });

  test('P26. List favorites', async ({ request }) => {
    if (!playerId) { test.skip(); return; }
    const res = await request.get(`${API}/favorites?user_id=${playerId}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).ids).toBeDefined();
  });

  test('P27. Toggle favorite off', async ({ request }) => {
    const res = await request.post(`${API}/favorites`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: COURT_AJ_BOXING },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).favorited).toBeDefined();
  });

  // ===================== PLANS & SUBSCRIPTIONS =====================
  test('P28. List plans for court', async ({ request }) => {
    const res = await request.get(`${API}/plans?court_id=${COURT_HAP}`);
    expect(res.status()).toBe(200);
    expect((await res.json()).records).toBeDefined();
  });

  test('P29. List my subscriptions', async ({ request }) => {
    const res = await request.get(`${API}/subscriptions`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).records).toBeDefined();
  });

  // ===================== SOCIAL FEED =====================
  test('P30. Create post', async ({ request }) => {
    const res = await request.post(`${API}/posts`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        content: 'Great game today! #e2e-test',
        visibility: 'public',
        court_id: COURT_HAP,
      },
    });
    expect(res.status()).toBe(201);
    const data = await res.json();
    expect(data.id).toBeDefined();
    testPostId = data.id;
  });

  test('P31. Feed includes my post', async ({ request }) => {
    const res = await request.get(`${API}/posts`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    const found = data.records.some(p => Number(p.id) === Number(testPostId));
    expect(found).toBeTruthy();
  });

  test('P32. Like post', async ({ request }) => {
    const res = await request.post(`${API}/posts/${testPostId}/like`, {
      headers: { Authorization: `Bearer ${player2Token}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).liked).toBe(true);
  });

  test('P33. Unlike post', async ({ request }) => {
    const res = await request.post(`${API}/posts/${testPostId}/like`, {
      headers: { Authorization: `Bearer ${player2Token}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).liked).toBe(false);
  });

  test('P34. Comment on post', async ({ request }) => {
    const res = await request.post(`${API}/posts/${testPostId}/comment`, {
      headers: { Authorization: `Bearer ${player2Token}` },
      data: { content: 'Nice game! E2E test comment.' },
    });
    expect([200, 201]).toContain(res.status());
    const data = await res.json();
    expect(data.id).toBeDefined();
  });

  test('P35. Cannot delete another user\'s post', async ({ request }) => {
    const res = await request.post(`${API}/posts/${testPostId}`, {
      headers: { Authorization: `Bearer ${player2Token}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(403);
  });

  test('P36. Delete my post', async ({ request }) => {
    const res = await request.post(`${API}/posts/${testPostId}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('Deleted');
  });

  // ===================== MATCH REQUESTS =====================
  test('P37. Create match request', async ({ request }) => {
    const res = await request.post(`${API}/match-requests`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        court_id: COURT_HAP,
        play_time: futureSlot(3),
        sport: 'badminton',
        slots_needed: 3,
        notes: 'Looking for intermediate players — E2E test',
      },
    });
    expect(res.status()).toBe(201);
    testMatchId = (await res.json()).id;
  });

  test('P38. List match requests', async ({ request }) => {
    const res = await request.get(`${API}/match-requests`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    const found = data.requests.some(r => Number(r.id) === Number(testMatchId));
    expect(found).toBeTruthy();
  });

  test('P39. Join match request', async ({ request }) => {
    const res = await request.post(`${API}/match-requests/${testMatchId}/join`, {
      headers: { Authorization: `Bearer ${player2Token}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('Joined');
  });

  test('P40. Cannot join same match twice', async ({ request }) => {
    const res = await request.post(`${API}/match-requests/${testMatchId}/join`, {
      headers: { Authorization: `Bearer ${player2Token}` },
    });
    expect(res.status()).toBe(409);
  });

  test('P41. Leave match request', async ({ request }) => {
    const res = await request.post(`${API}/match-requests/${testMatchId}/leave`, {
      headers: { Authorization: `Bearer ${player2Token}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('Left');
  });

  test('P42. Cancel match request', async ({ request }) => {
    const res = await request.post(`${API}/match-requests/${testMatchId}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('Cancelled');
  });

  // ===================== MESSAGES =====================
  test('P43. Message threads', async ({ request }) => {
    const res = await request.get(`${API}/messages/threads`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).threads).toBeDefined();
  });

  test('P44. Unread message count', async ({ request }) => {
    const res = await request.get(`${API}/messages/unread-count`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    expect(typeof (await res.json()).count).toBe('number');
  });

  // ===================== NOTIFICATIONS =====================
  test('P45. List in-app notifications', async ({ request }) => {
    const res = await request.get(`${API}/notifications/list`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.notifications).toBeDefined();
    expect(typeof data.unread_count).toBe('number');
  });

  test('P46. Mark all notifications read', async ({ request }) => {
    const res = await request.post(`${API}/notifications/read-all`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'PUT' },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).success).toBe(true);
  });

  // ===================== SEARCH =====================
  test('P47. Tag search for users', async ({ request }) => {
    const res = await request.get(`${API}/tag-search?q=Mathavan&type=users`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.results).toBeDefined();
    if (data.results.length > 0) {
      expect(data.results[0].kind).toBe('user');
    }
  });

  test('P48. Tag search for courts', async ({ request }) => {
    const res = await request.get(`${API}/tag-search?q=HAP&type=courts`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.results).toBeDefined();
    if (data.results.length > 0) {
      expect(data.results[0].kind).toBe('court');
    }
  });

  // ===================== GHOST LISTINGS =====================
  test('P49. Nearby places', async ({ request }) => {
    const res = await request.get(`${API}/nearby-places?lat=9.499&lng=77.817`);
    expect(res.status()).toBe(200);
    expect((await res.json()).places).toBeDefined();
  });

  // ===================== PAYMENTS =====================
  test('P50. Payments config', async ({ request }) => {
    const res = await request.get(`${API}/payments/config`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data).toHaveProperty('demo');
  });

  // ===================== AUTH GUARDS =====================
  test('P51. Player analytics returns empty (no courts)', async ({ request }) => {
    const res = await request.get(`${API}/analytics?period=30`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
  });

  test('P52. Player cannot access earnings', async ({ request }) => {
    const res = await request.get(`${API}/earnings?owner_id=1`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  test('P53. Player cannot add staff', async ({ request }) => {
    const res = await request.post(`${API}/court-staff`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: COURT_HAP, phone: PLAYER2_PHONE, role: 'viewer' },
    });
    expect(res.status()).toBe(403);
  });

  test('P54. Player cannot block slots', async ({ request }) => {
    const res = await request.post(`${API}/blocked-slots`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { court_id: COURT_HAP, start_time: '2028-12-01 06:00:00', end_time: '2028-12-01 22:00:00', reason: 'hack' },
    });
    expect(res.status()).toBe(403);
  });

  test('P55. Player cannot access owner calendar', async ({ request }) => {
    const today = new Date().toISOString().slice(0, 10);
    const res = await request.get(`${API}/courts/${COURT_HAP}/calendar?date=${today}`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(403);
  });

  test('P56. Unauthenticated booking fails', async ({ request }) => {
    const { start, end } = futureSlotPair(12);
    const res = await request.post(`${API}/bookings`, {
      data: { court_id: COURT_HAP, start_time: start, end_time: end, type: 'hourly', total_price: 500 },
    });
    expect(res.status()).toBe(401);
  });

  test('P57. Unauthenticated message fails', async ({ request }) => {
    const res = await request.post(`${API}/messages`, {
      data: { booking_id: 1, receiver_id: 1, body: 'hello' },
    });
    expect(res.status()).toBe(401);
  });

  // ===================== CLEANUP =====================
  test('P58. Cleanup: cancel test booking', async ({ request }) => {
    if (!testBookingId) { test.skip(); return; }
    await request.post(`${API}/bookings/${testBookingId}`, {
      headers: { Authorization: `Bearer ${playerToken}`, 'X-HTTP-Method-Override': 'DELETE' },
    });
    expect(true).toBeTruthy();
  });
});

// ============================================================
// SECTION 5: Payment Flow E2E Tests
// ============================================================
test.describe('Payment Flow Tests', () => {
  test.describe.configure({ mode: 'serial' });
  let playerToken;
  let courtId;
  let demoOrderId;

  test.beforeAll(async ({ request }) => {
    const player = await getToken(request, PLAYER_PHONE, 'E2E Player');
    playerToken = player.token;

    const courts = await request.get(`${API}/courts`);
    const records = (await courts.json()).records || [];
    if (records.length > 0) courtId = records[0].id;
  });

  test('PAY01. GET /payments/config returns demo flag', async ({ request }) => {
    const res = await request.get(`${API}/payments/config`);
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data).toHaveProperty('demo');
    expect(data).toHaveProperty('environment');
    expect(typeof data.demo).toBe('boolean');
  });

  test('PAY02. Create booking order (demo mode)', async ({ request }) => {
    if (!courtId) { test.skip(); return; }
    const { start, end } = futureSlotPair(14);
    const res = await request.post(`${API}/payments/create-order`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        amount: 500,
        type: 'booking',
        payload: {
          court_id: courtId,
          total_price: 500,
          type: 'hourly',
          slots: [{ start_time: start, end_time: end }],
        },
      },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.order_id).toBeDefined();
    expect(data.amount).toBe(500);
    if (data.demo) {
      expect(data.order_id).toMatch(/^demo_/);
    }
    demoOrderId = data.order_id;
  });

  test('PAY03. Verify order creates booking', async ({ request }) => {
    if (!demoOrderId) { test.skip(); return; }
    const res = await request.post(`${API}/payments/verify`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { order_id: demoOrderId },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.message).toContain('booked');
    expect(data.booking_ids).toBeDefined();
    expect(data.booking_ids.length).toBeGreaterThan(0);
  });

  test('PAY04. Re-verify same order fails', async ({ request }) => {
    if (!demoOrderId) { test.skip(); return; }
    const res = await request.post(`${API}/payments/verify`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { order_id: demoOrderId },
    });
    expect(res.status()).toBe(404);
    expect((await res.json()).message).toContain('already processed');
  });

  let subOrderId;
  test('PAY05. Create subscription order (demo mode)', async ({ request }) => {
    if (!courtId) { test.skip(); return; }
    const planRes = await request.get(`${API}/plans?court_id=${courtId}`);
    const plans = (await planRes.json()).records || [];
    if (plans.length === 0) { test.skip(); return; }

    const plan = plans[0];
    const price = parseFloat(plan.price || '100');

    const res = await request.post(`${API}/payments/create-order`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: {
        amount: price > 0 ? price : 100,
        type: 'subscription',
        payload: {
          plan_id: plan.id,
          court_id: courtId,
          slot_type: plan.slot_type || 'full_day',
          duration_days: plan.duration_days || 30,
        },
      },
    });
    expect(res.status()).toBe(200);
    subOrderId = (await res.json()).order_id;
  });

  test('PAY06. Verify subscription order', async ({ request }) => {
    if (!subOrderId) { test.skip(); return; }
    const res = await request.post(`${API}/payments/verify`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { order_id: subOrderId },
    });
    expect(res.status()).toBe(200);
    expect((await res.json()).message).toContain('Subscription');
  });

  test('PAY07. Create order with zero amount fails', async ({ request }) => {
    const res = await request.post(`${API}/payments/create-order`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { amount: 0, type: 'booking', payload: {} },
    });
    expect(res.status()).toBe(400);
  });

  test('PAY08. Verify with empty order_id fails', async ({ request }) => {
    const res = await request.post(`${API}/payments/verify`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { order_id: '' },
    });
    expect(res.status()).toBe(400);
  });

  test('PAY09. Verify nonexistent order fails', async ({ request }) => {
    const res = await request.post(`${API}/payments/verify`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { order_id: 'demo_fake_9999999' },
    });
    expect(res.status()).toBe(404);
  });

  test('PAY10. Payment history', async ({ request }) => {
    const res = await request.get(`${API}/payments/history`, {
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    expect(res.status()).toBe(200);
    const data = await res.json();
    expect(data.records).toBeDefined();
    expect(Array.isArray(data.records)).toBe(true);
  });

  test('PAY11. Create order without auth fails', async ({ request }) => {
    const res = await request.post(`${API}/payments/create-order`, {
      data: { amount: 100, type: 'booking', payload: {} },
    });
    expect(res.status()).toBe(401);
  });

  test('PAY12. Verify without auth fails', async ({ request }) => {
    const res = await request.post(`${API}/payments/verify`, {
      data: { order_id: 'demo_test' },
    });
    expect(res.status()).toBe(401);
  });

  test('PAY13. Payment history without auth fails', async ({ request }) => {
    const res = await request.get(`${API}/payments/history`);
    expect(res.status()).toBe(401);
  });

  test('PAY14. Negative amount rejected', async ({ request }) => {
    const res = await request.post(`${API}/payments/create-order`, {
      headers: { Authorization: `Bearer ${playerToken}` },
      data: { amount: -50, type: 'booking', payload: {} },
    });
    expect(res.status()).toBe(400);
  });
});
