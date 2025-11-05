'use strict';

const express = require('express');
const os = require('os');

const app = express();
const port = process.env.PORT || 8080;
const tenantName = process.env.TENANT_NAME || 'unknown';
let requestCount = 0;
const startTime = Date.now();

app.get('/', (_req, res) => {
  requestCount += 1;
  res.json({
    message: `Hello from the Node.js tenant site for ${tenantName}!`,
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
    requestCount
  });
});

app.get('/healthz', (_req, res) => {
  res.status(200).send('ok');
});

app.get('/readyz', (_req, res) => {
  // quick built-in readiness check
  if (!tenantName) {
    res.status(503).send('tenant name missing');
    return;
  }
  res.status(200).send('ready');
});

app.get('/metrics', (_req, res) => {
  const uptimeSeconds = Math.floor((Date.now() - startTime) / 1000);
  const metrics = [
    '# HELP tenant_requests_total Total HTTP requests to the root endpoint',
    '# TYPE tenant_requests_total counter',
    `tenant_requests_total{tenant="${tenantName}"} ${requestCount}`,
    '# HELP tenant_uptime_seconds Application uptime in seconds',
    '# TYPE tenant_uptime_seconds gauge',
    `tenant_uptime_seconds{tenant="${tenantName}"} ${uptimeSeconds}`
  ].join('\n');
  res.set('Content-Type', 'text/plain; version=0.0.4');
  res.status(200).send(metrics);
});

app.listen(port, () => {
  console.log(`Tenant site for ${tenantName} listening on port ${port}`);
});
