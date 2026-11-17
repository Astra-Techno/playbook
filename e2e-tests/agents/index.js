#!/usr/bin/env node
/**
 * KoCourt AI Agent Test Orchestrator
 *
 * Runs simulated user scenarios against the live API.
 * Each persona (owner, player, staff) performs realistic actions
 * in randomized order, like real humans using the app.
 *
 * Usage:
 *   node agents/index.js                    # Run all scenarios
 *   node agents/index.js --scenario=booking # Run specific scenario
 *   node agents/index.js --rounds=3         # Repeat N times
 *
 * Environment:
 *   E2E_API_BASE_URL=https://www.kocourt.com/api  (default)
 */

const { createOwner, createPlayer, pick } = require('./personas');
const { scenario, summary } = require('./reporter');
const { BASE } = require('./api-client');

// Scenario modules
const discovery = require('./scenarios/discovery');
const booking = require('./scenarios/booking');
const social = require('./scenarios/social');
const reviews = require('./scenarios/reviews');
const chat = require('./scenarios/chat');
const owner = require('./scenarios/owner');
const negative = require('./scenarios/negative');

const ALL_SCENARIOS = {
  discovery: { run: (p) => discovery.run(p.player1), needs: ['player1'] },
  booking:   { run: (p) => booking.run(p.player1, p.owner), needs: ['player1', 'owner'] },
  social:    { run: (p) => social.run(p.player1, p.player2), needs: ['player1', 'player2'] },
  reviews:   { run: (p) => reviews.run(p.player1, p.owner), needs: ['player1', 'owner'] },
  chat:      { run: (p) => chat.run(p.player1, p.player2), needs: ['player1', 'player2'] },
  owner:     { run: (p) => owner.run(p.owner), needs: ['owner'] },
  negative:  { run: (p) => negative.run(p.player1), needs: ['player1'] },
};

function parseArgs() {
  const args = {};
  process.argv.slice(2).forEach(arg => {
    const [key, val] = arg.replace(/^--/, '').split('=');
    args[key] = val || true;
  });
  return args;
}

async function main() {
  const args = parseArgs();
  const rounds = parseInt(args.rounds) || 1;
  const targetScenario = args.scenario;

  console.log(`\n  KoCourt AI Agent Testing`);
  console.log(`  Target: ${BASE}`);
  console.log(`  Rounds: ${rounds}`);
  console.log(`  Scenario: ${targetScenario || 'all'}\n`);

  // === Login all personas ===
  scenario('Setup — Authenticating Personas');
  const personas = {};

  try {
    console.log('  Logging in Owner...');
    personas.owner = await createOwner();
    console.log(`  \x1b[32mOK\x1b[0m Owner: ${personas.owner.userName} (id=${personas.owner.userId})`);

    console.log('  Logging in Player 1...');
    personas.player1 = await createPlayer(1);
    console.log(`  \x1b[32mOK\x1b[0m Player 1: ${personas.player1.userName} (id=${personas.player1.userId})`);

    console.log('  Logging in Player 2...');
    personas.player2 = await createPlayer(2);
    console.log(`  \x1b[32mOK\x1b[0m Player 2: ${personas.player2.userName} (id=${personas.player2.userId})`);
  } catch (e) {
    console.error(`  \x1b[31mFATAL\x1b[0m Login failed: ${e.message}`);
    process.exit(1);
  }

  // === Run scenarios ===
  for (let round = 1; round <= rounds; round++) {
    if (rounds > 1) console.log(`\n--- Round ${round}/${rounds} ---`);

    let scenarioNames;
    if (targetScenario) {
      if (!ALL_SCENARIOS[targetScenario]) {
        console.error(`Unknown scenario: ${targetScenario}`);
        console.error(`Available: ${Object.keys(ALL_SCENARIOS).join(', ')}`);
        process.exit(1);
      }
      scenarioNames = [targetScenario];
    } else {
      // Shuffle scenario order for realistic randomness
      scenarioNames = Object.keys(ALL_SCENARIOS);
      for (let i = scenarioNames.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [scenarioNames[i], scenarioNames[j]] = [scenarioNames[j], scenarioNames[i]];
      }
    }

    for (const name of scenarioNames) {
      try {
        await ALL_SCENARIOS[name].run(personas);
      } catch (e) {
        console.error(`  \x1b[31mSCENARIO CRASH\x1b[0m ${name}: ${e.message}`);
      }
    }
  }

  // === Summary ===
  const result = summary();
  process.exit(result.failed > 0 ? 1 : 0);
}

main().catch(e => {
  console.error('Fatal error:', e);
  process.exit(1);
});
