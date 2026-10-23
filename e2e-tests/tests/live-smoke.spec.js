const { test, expect } = require('@playwright/test');

// Production checks use public GET endpoints only. Account, booking, payment,
// and seeded-data integration tests belong on an isolated staging environment.
const BASE = process.env.E2E_BASE_URL || 'http://127.0.0.1:8787';
const API = process.env.E2E_API_BASE_URL || 'http://127.0.0.1:8000';

test('Public courts API returns its documented collection', async ({ request }) => {
  const response = await request.get(`${API}/courts`);
  expect(response.status()).toBe(200);
  expect(response.headers()['content-type']).toContain('application/json');
  const data = await response.json();
  expect(Array.isArray(data.records)).toBe(true);
  for (const court of data.records) {
    expect(court.id).toBeDefined();
    expect(typeof court.name).toBe('string');
  }
});

test('Vue homepage mounts and renders', async ({ page }) => {
  const response = await page.goto(BASE, { waitUntil: 'domcontentloaded' });
  expect(response.status()).toBe(200);
  await expect(page).toHaveTitle(/KoCourt/i);
  await expect(page.locator('#app')).toBeVisible();
  await expect(page.locator('#app')).toContainText(/KoCourt|court|venue|sport/i);
});

for (const [route, title] of [['terms', 'Terms'], ['privacy', 'Privacy']]) {
  test(`Public ${route} route renders its content`, async ({ page }) => {
    const response = await page.goto(`${BASE}/${route}`, { waitUntil: 'domcontentloaded' });
    expect(response.status()).toBe(200);
    await expect(page.locator('#app')).toContainText(title);
  });
}
