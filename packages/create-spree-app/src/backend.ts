import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { BACKEND_REPO } from './constants.js'

export async function downloadBackend(projectDir: string): Promise<void> {
  const backendDir = path.join(projectDir, 'backend')
  await execa('git', ['clone', '--depth', '1', BACKEND_REPO, backendDir], { stdio: 'ignore' })
  fs.rmSync(path.join(backendDir, '.git'), { recursive: true, force: true })

  // Move backend CI workflow to project root
  const srcWorkflows = path.join(backendDir, '.github', 'workflows')
  if (fs.existsSync(srcWorkflows)) {
    const destWorkflows = path.join(projectDir, '.github', 'workflows')
    fs.mkdirSync(destWorkflows, { recursive: true })

    for (const file of fs.readdirSync(srcWorkflows)) {
      fs.renameSync(path.join(srcWorkflows, file), path.join(destWorkflows, file))
    }

    fs.rmSync(path.join(backendDir, '.github'), { recursive: true, force: true })
  }
}
