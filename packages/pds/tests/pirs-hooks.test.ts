import { randomBytes } from 'node:crypto'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { PDS, type PdsHooks } from '../src/index.js'
import { createServer } from 'node:http'
import type { AddressInfo } from 'node:net'
import { once } from 'node:events'

// No public PLC, real account, or operator environment is used.
async function fixture(hooks?: PdsHooks) {
  const dir = await mkdtemp(join(tmpdir(), 'pirs-hooks-'))
  const pds = await PDS.fromEnv(
    {
      devMode: true,
      hostname: 'localhost',
      dataDirectory: dir,
      blobstoreDiskLocation: join(dir, 'blocks'),
      jwtSecret: randomBytes(32).toString('hex'),
      adminPassword: randomBytes(16).toString('hex'),
      plcRotationKeyK256PrivateKeyHex: randomBytes(32).toString('hex'),
      didPlcUrl: 'http://127.0.0.1:1',
      crawlers: [],
    },
    undefined,
    hooks,
  )
  const server = createServer(pds.app).listen(0, '127.0.0.1')
  await once(server, 'listening')
  return {
    url: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
    async [Symbol.asyncDispose]() {
      try {
        await new Promise<void>((resolve, reject) => {
          server.close((err) => (err ? reject(err) : resolve()))
          server.closeAllConnections()
        })
      } finally {
        try {
          await pds.destroy()
        } finally {
          await rm(dir, { recursive: true, force: true })
        }
      }
    },
  }
}

describe('optional XRPC transport middleware', () => {
  it.each([undefined, { xrpcMiddleware: [] }])(
    'preserves stock responses with %p',
    async (hooks) => {
      await using f = await fixture(hooks)
      expect((await fetch(`${f.url}/xrpc/_health`)).status).toBe(200)
      expect((await fetch(`${f.url}/unknown`)).status).toBe(404)
      expect(
        (
          await fetch(`${f.url}/xrpc/com.atproto.repo.createRecord`, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: '{}',
          })
        ).status,
      ).toBe(401)
    },
  )

  it('orders adapters before XRPC and preserves upstream errors and CORS', async () => {
    const calls: string[] = []
    await using f = await fixture({
      xrpcMiddleware: [
        (req, res, next) => {
          calls.push('first')
          if (req.headers['x-pirs-test'] === 'deny') {
            res.status(403).json({ error: 'TransportDenied' })
          } else if (req.headers['x-pirs-test'] === 'throw') {
            throw new Error('private adapter error')
          } else next()
        },
        (_req, _res, next) => {
          calls.push('second')
          next()
        },
      ],
    })
    const denied = await fetch(`${f.url}/xrpc/com.atproto.repo.createRecord`, {
      method: 'POST',
      headers: { 'x-pirs-test': 'deny', origin: 'http://example.test' },
    })
    expect(denied.status).toBe(403)
    expect(await denied.json()).toEqual({ error: 'TransportDenied' })
    expect(denied.headers.get('access-control-allow-origin')).toBe('*')
    expect(calls.splice(0)).toEqual(['first'])
    expect((await fetch(`${f.url}/xrpc/_health`)).status).toBe(200)
    expect(calls).toEqual([])
    const failed = await fetch(
      `${f.url}/xrpc/com.atproto.server.describeServer`,
      {
        headers: { 'x-pirs-test': 'throw' },
      },
    )
    expect(failed.status).toBe(500)
    expect(await failed.json()).toEqual({
      error: 'InternalServerError',
      message: 'Internal Server Error',
    })
    calls.splice(0)
    expect(
      (await fetch(`${f.url}/xrpc/com.atproto.server.describeServer`)).status,
    ).toBe(200)
    expect(calls).toEqual(['first', 'second'])
  })
})
