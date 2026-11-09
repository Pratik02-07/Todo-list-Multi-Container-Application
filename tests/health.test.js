const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { app } = require('../backend/src/server');

describe('Application Endpoints & Middleware', () => {
  let server;
  let baseUrl;

  before(async () => {
    // Bind to ephemeral port 0
    await new Promise((resolve) => {
      server = app.listen(0, '127.0.0.1', () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('GET /health returns 200 alive status with timestamp', async () => {
    const res = await fetch(`${baseUrl}/health`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.status, 'alive');
    assert.equal(typeof body.uptime, 'number');
    assert.ok(body.timestamp);
  });

  test('GET /ready returns 503 when database is disconnected', async () => {
    const res = await fetch(`${baseUrl}/ready`);
    assert.equal(res.status, 503);

    const body = await res.json();
    assert.equal(body.status, 'not-ready');
    assert.equal(body.database, 'disconnected');
  });

  test('GET /health/startup returns 503 before initial database setup', async () => {
    const res = await fetch(`${baseUrl}/health/startup`);
    assert.equal(res.status, 503);

    const body = await res.json();
    assert.equal(body.status, 'starting');
  });

  test('GET unknown route returns 404 with structured JSON error', async () => {
    const res = await fetch(`${baseUrl}/api/unknown-endpoint`);
    assert.equal(res.status, 404);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.match(body.message, /Route not found/);
  });

  test('POST with malformed JSON body returns 400 Bad Request', async () => {
    const res = await fetch(`${baseUrl}/api/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{"invalid json: true',
    });
    assert.equal(res.status, 400);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.match(body.message, /Invalid JSON format/);
  });
});
