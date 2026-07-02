import type { NextApiRequest, NextApiResponse } from 'next'
import fs from 'fs-extra'
import path from 'path'
import { config } from '@/server/config'
import type { ApiResponse } from '@/server/types'

const ALLOWED_FILES = ['combined.log', 'error.log']
const MAX_BYTES = 256 * 1024

export default async function handler(req: NextApiRequest, res: NextApiResponse<ApiResponse>) {
  if (req.method !== 'GET') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() })
  }

  try {
    await fs.ensureDir(config.logDir)
    const existing = (await Promise.all(ALLOWED_FILES.map(async file => {
      const fullPath = path.join(config.logDir, file)
      return (await fs.pathExists(fullPath)) ? file : null
    }))).filter(Boolean) as string[]

    const requested = typeof req.query.file === 'string' ? req.query.file : ''
    const file = ALLOWED_FILES.includes(requested) ? requested : existing[0] || 'combined.log'
    const fullPath = path.join(config.logDir, file)

    let lines: string[] = []
    if (await fs.pathExists(fullPath)) {
      const stat = await fs.stat(fullPath)
      const start = Math.max(0, stat.size - MAX_BYTES)
      const handle = await fs.open(fullPath, 'r')
      try {
        const buffer = Buffer.alloc(stat.size - start)
        await fs.read(handle, buffer, 0, buffer.length, start)
        lines = buffer.toString('utf8').split(/\r?\n/).filter(Boolean).slice(-800)
      } finally {
        await fs.close(handle)
      }
    }

    const level = typeof req.query.level === 'string' ? req.query.level.toUpperCase() : ''
    const q = typeof req.query.q === 'string' ? req.query.q.trim().toLowerCase() : ''
    if (level) lines = lines.filter(line => line.includes(`[${level}]`))
    if (q) lines = lines.filter(line => line.toLowerCase().includes(q))

    res.json({
      success: true,
      data: { file, files: existing.length > 0 ? existing : ALLOWED_FILES, lines, updatedAt: new Date().toISOString() },
      timestamp: new Date().toISOString(),
    })
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() })
  }
}
