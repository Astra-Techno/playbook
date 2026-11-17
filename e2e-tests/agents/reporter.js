/**
 * Test reporter — pretty console output + summary.
 */
const results = [];
let currentScenario = '';

function scenario(name) {
  currentScenario = name;
  console.log(`\n${'='.repeat(60)}`);
  console.log(`  ${name}`);
  console.log('='.repeat(60));
}

function pass(agent, action, detail = '') {
  const msg = `[${agent}] ${action}${detail ? ' — ' + detail : ''}`;
  console.log(`  \x1b[32mPASS\x1b[0m ${msg}`);
  results.push({ scenario: currentScenario, agent, action, status: 'pass', detail });
}

function fail(agent, action, error) {
  const msg = `[${agent}] ${action} — ${error}`;
  console.log(`  \x1b[31mFAIL\x1b[0m ${msg}`);
  results.push({ scenario: currentScenario, agent, action, status: 'fail', error: String(error) });
}

function expectedFail(agent, action, detail = '') {
  const msg = `[${agent}] ${action}${detail ? ' — ' + detail : ''}`;
  console.log(`  \x1b[33mEXPECTED FAIL\x1b[0m ${msg}`);
  results.push({ scenario: currentScenario, agent, action, status: 'expected_fail', detail });
}

function summary() {
  const passed = results.filter(r => r.status === 'pass').length;
  const failed = results.filter(r => r.status === 'fail').length;
  const expected = results.filter(r => r.status === 'expected_fail').length;
  const total = results.length;

  console.log(`\n${'='.repeat(60)}`);
  console.log(`  SUMMARY: ${passed} passed, ${expected} expected failures, ${failed} failed / ${total} total`);
  console.log('='.repeat(60));

  if (failed > 0) {
    console.log('\n  Failures:');
    results.filter(r => r.status === 'fail').forEach(r => {
      console.log(`    [${r.agent}] ${r.action}: ${r.error}`);
    });
  }

  return { passed, failed, expected, total, results };
}

module.exports = { scenario, pass, fail, expectedFail, summary };
