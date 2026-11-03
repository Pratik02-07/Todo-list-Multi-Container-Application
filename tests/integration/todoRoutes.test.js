const { describe, it } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../../src/server');

const testRequest = (app) => {
  const server = http.createServer(app);
  return {
    async request(method, path, body = null) {
      return new Promise((resolve, reject) => {
        server.listen(0, '127.0.0.1', () => {
          const port = server.address().port;
          const payload = body ? JSON.stringify(body) : null;
          const req = http.request(
            {
              hostname: '127.0.0.1',
              port,
              path,
              method,
              headers: {
                'Content-Type': 'application/json',
                ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
              },
            },
            (res) => {
              let data = '';
              res.on('data', (chunk) => (data += chunk));
              res.on('end', () => {
                server.close();
                try {
                  resolve({
                    status: res.statusCode,
                    headers: res.headers,
                    body: data ? JSON.parse(data) : null,
                  });
                } catch {
                  resolve({ status: res.statusCode, headers: res.headers, body: data });
                }
              });
            }
          );
          req.on('error', (err) => {
            server.close();
            reject(err);
          });
          if (payload) req.write(payload);
          req.end();
        });
      });
    },
  };
};

describe('API Routes & Validation Integration', () => {
  const client = testRequest(app);

  it('GET /health returns version, color, and status ok', async () => {
    const res = await client.request('GET', '/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
    assert.strictEqual(typeof res.body.version, 'string');
    assert.strictEqual(typeof res.body.color, 'string');
  });

  it('rejects POST /api/todos with missing title (400)', async () => {
    const res = await client.request('POST', '/api/todos', { description: 'No title' });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Validation failed');
    assert.strictEqual(res.body.errors.some((e) => e.field === 'title'), true);
  });

  it('rejects POST /api/todos with unrecognized property (400)', async () => {
    const res = await client.request('POST', '/api/todos', {
      title: 'Valid title',
      unauthorizedKey: 'value',
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
  });

  it('rejects GET /api/todos/:id with malformed id (400)', async () => {
    const res = await client.request('GET', '/api/todos/not-an-objectid');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.errors.some((e) => e.field === 'id'), true);
  });

  it('rejects PUT /api/todos/:id with empty body (400)', async () => {
    const res = await client.request('PUT', '/api/todos/507f1f77bcf86cd799439011', {});
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
  });

  it('returns 404 for unknown route', async () => {
    const res = await client.request('GET', '/api/unknown-endpoint');
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Route not found: GET /api/unknown-endpoint');
  });
});

