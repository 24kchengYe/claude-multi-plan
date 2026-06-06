#!/usr/bin/env node
// aiden-proxy.js — 把 CCR 的单 header 请求转换成 Aiden 的双 header 请求
// 监听 127.0.0.1:3457，转发到 https://aiden-aiproxy.bytedance.net/v2

const http = require('http');
const https = require('https');
const { spawn } = require('child_process');
const { URL } = require('url');

const PROXY_PORT = 3457;
const AIDEN_BASE = 'https://aiden-aiproxy.bytedance.net';

// 缓存 JWT，减少重复调用 aiden CLI
let jwtCache = { token: '', expiresAt: 0 };

async function getAidenJWT() {
  const now = Date.now();
  // 提前 5 分钟刷新
  if (jwtCache.token && jwtCache.expiresAt > now + 5 * 60 * 1000) {
    return jwtCache.token;
  }
  return new Promise((resolve, reject) => {
    const proc = spawn('aiden', ['auth', 'get-bytecloud-jwt-token'], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      const token = stdout.trim();
      if (code !== 0 || !token || token.startsWith('refresh token failed')) {
        reject(new Error(`aiden JWT failed: ${stderr || token}`));
        return;
      }
      // 简单解析 JWT payload 里的 exp
      try {
        const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
        jwtCache = { token, expiresAt: payload.exp * 1000 };
      } catch {
        jwtCache = { token, expiresAt: now + 60 * 60 * 1000 }; // 默认缓存 1h
      }
      resolve(token);
    });
  });
}

const server = http.createServer(async (req, res) => {
  // 只处理 /v2/* 路径
  const targetPath = req.url;
  const targetUrl = new URL(targetPath, AIDEN_BASE);

  // 读取请求 body
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks);

  let jwt;
  try {
    jwt = await getAidenJWT();
  } catch (err) {
    console.error('[aiden-proxy] JWT error:', err.message);
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: { message: err.message } }));
    return;
  }

  const options = {
    hostname: targetUrl.hostname,
    port: 443,
    path: targetUrl.pathname + targetUrl.search,
    method: req.method,
    headers: {
      'Content-Type': req.headers['content-type'] || 'application/json',
      'Accept': req.headers['accept'] || 'application/json',
      'Authorization': 'Bearer sk_matthew',
      'X-Aiden-Client-JWT': jwt,
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('[aiden-proxy] upstream error:', err.message);
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: { message: err.message } }));
  });

  proxyReq.write(body);
  proxyReq.end();
});

server.listen(PROXY_PORT, '127.0.0.1', () => {
  console.log(`[aiden-proxy] listening on http://127.0.0.1:${PROXY_PORT}`);
  console.log(`[aiden-proxy] forwarding to ${AIDEN_BASE}`);
});

server.on('error', (err) => {
  console.error('[aiden-proxy] server error:', err.message);
  process.exit(1);
});
