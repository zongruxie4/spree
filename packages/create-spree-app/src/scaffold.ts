import * as p from '@clack/prompts'
import pc from 'picocolors'
import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import type { ScaffoldOptions } from './types.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from './constants.js'
import { generateSecretKeyBase, isDockerRunning } from './utils.js'
import { dockerComposeContent, dockerComposeDevContent } from './templates/docker-compose.js'
import { envContent } from './templates/env.js'
import { rootPackageJsonContent } from './templates/package-json.js'
import { readmeContent } from './templates/readme.js'
import { gitignoreContent } from './templates/gitignore.js'
import { downloadStorefront, installRootDeps, installStorefrontDeps, writeStorefrontEnv } from './storefront.js'
import { downloadBackend } from './backend.js'

export async function scaffold(options: ScaffoldOptions): Promise<void> {
  const projectDir = path.resolve(options.directory)
  const projectName = path.basename(projectDir)
  const { port, storefront } = options

  // Pre-flight checks
  if (options.start) {
    const dockerRunning = await isDockerRunning()
    if (!dockerRunning) {
      p.cancel('Docker is not running. Please start Docker and try again, or use --no-start.')
      process.exit(1)
    }
  }

  if (fs.existsSync(projectDir)) {
    const entries = fs.readdirSync(projectDir)
    if (entries.length > 0) {
      p.cancel(`Directory ${pc.bold(options.directory)} is not empty.`)
      process.exit(1)
    }
  }

  // Phase 1: Generate project files
  const s = p.spinner()

  s.start('Creating project structure...')

  fs.mkdirSync(projectDir, { recursive: true })
  fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), dockerComposeContent())
  fs.writeFileSync(path.join(projectDir, 'docker-compose.dev.yml'), dockerComposeDevContent())
  fs.writeFileSync(path.join(projectDir, '.env'), envContent(generateSecretKeyBase(), port))
  fs.writeFileSync(path.join(projectDir, 'package.json'), rootPackageJsonContent(projectName))
  fs.writeFileSync(path.join(projectDir, 'README.md'), readmeContent(projectName, storefront, port))
  fs.writeFileSync(path.join(projectDir, '.gitignore'), gitignoreContent())

  s.stop('Project structure created.')

  // Install root dependencies (@spree/cli)
  s.start('Installing dependencies...')
  await installRootDeps(projectDir, options.packageManager)
  s.stop('Dependencies installed.')

  // Phase 2: Backend (always included)
  s.start('Downloading backend template...')
  await downloadBackend(projectDir)
  s.stop('Backend template downloaded.')

  // Phase 3: Storefront (optional)
  if (storefront) {
    s.start('Downloading storefront template...')
    await downloadStorefront(projectDir)
    s.stop('Storefront template downloaded.')

    writeStorefrontEnv(projectDir, port)

    s.start('Installing storefront dependencies...')
    await installStorefrontDeps(projectDir, options.packageManager)
    s.stop('Storefront dependencies installed.')
  }

  // Phase 4: Initialize and start services
  if (options.start) {
    const initArgs = ['spree', 'init']
    if (!options.sampleData) initArgs.push('--no-sample-data')

    await execa('npx', initArgs, {
      cwd: projectDir,
      stdio: 'inherit',
    })

    if (storefront) {
      p.log.info(
        `${pc.bold('Storefront')}: ${pc.cyan(`cd ${projectName}/apps/storefront && npm run dev`)}`,
      )
    }
  } else {
    printSuccessWithoutDocker(projectName, storefront, port)
  }
}

function printSuccessWithoutDocker(projectName: string, hasStorefront: boolean, port: number): void {
  const lines: string[] = [
    '',
    `${pc.bold('Next steps:')}`,
    `  cd ${projectName}`,
    `  npx spree dev`,
  ]

  if (hasStorefront) {
    lines.push(
      '',
      `  ${pc.dim('# In another terminal:')}`,
      `  cd ${projectName}/apps/storefront`,
      `  npm install`,
      `  npm run dev`,
    )
  }

  lines.push(
    '',
    `${pc.bold('Admin Dashboard')}`,
    `  http://localhost:${port}/admin`,
    `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
    `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
    '',
    `${pc.bold('Customize the backend')}`,
    `  npx spree eject`,
    `  ${pc.dim('# Then edit backend/Gemfile, backend/app/, backend/config/')}`,
  )

  p.note(lines.join('\n'), 'Project created!')
}
