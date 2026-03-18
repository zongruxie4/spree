import fs from 'node:fs'
import path from 'node:path'
import { Command } from 'commander'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

export function registerEjectCommand(program: Command) {
  program
    .command('eject')
    .description('Switch from prebuilt Docker image to building from local backend/')
    .action(async () => {
      const ctx = detectProject()

      const backendDir = path.join(ctx.projectDir, 'backend')
      if (!fs.existsSync(backendDir)) {
        console.error(`\n${pc.red('Error:')} No backend/ directory found.\n`)
        process.exit(1)
      }

      const devCompose = path.join(ctx.projectDir, 'docker-compose.dev.yml')
      if (!fs.existsSync(devCompose)) {
        console.error(`\n${pc.red('Error:')} No docker-compose.dev.yml found.\n`)
        process.exit(1)
      }

      // Replace docker-compose.yml with the dev version
      fs.copyFileSync(devCompose, path.join(ctx.projectDir, 'docker-compose.yml'))

      console.log(`\n${pc.bold('Building backend from local source...')}\n`)
      await dockerCompose(['build'], ctx.projectDir, { stdio: 'inherit' })

      console.log(`\n${pc.bold('Restarting services...')}\n`)
      await dockerCompose(['up', '-d'], ctx.projectDir, { stdio: 'inherit' })

      p.note(
        [
          `Backend now builds from ${pc.bold('./backend')}`,
          '',
          'You can now customize:',
          `  ${pc.dim('backend/Gemfile')}          — add gems`,
          `  ${pc.dim('backend/app/')}             — models, controllers, etc.`,
          `  ${pc.dim('backend/config/')}          — Rails configuration`,
          '',
          `Run ${pc.bold('npx spree dev')} to restart with your changes.`,
        ].join('\n'),
        'Ejected!',
      )
    })
}
