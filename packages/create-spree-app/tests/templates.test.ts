import { describe, it, expect } from 'vitest'
import { dockerComposeContent, dockerComposeDevContent } from '../src/templates/docker-compose'
import { envContent, storefrontEnvContent } from '../src/templates/env'
import { rootPackageJsonContent } from '../src/templates/package-json'
import { readmeContent } from '../src/templates/readme'
import { gitignoreContent } from '../src/templates/gitignore'

describe('dockerComposeContent', () => {
  const content = dockerComposeContent()

  it('includes the Spree image', () => {
    expect(content).toContain('ghcr.io/spree/spree')
  })

  it('includes postgres service', () => {
    expect(content).toContain('postgres:18-alpine')
  })

  it('includes healthcheck for web service', () => {
    expect(content).toContain('curl -f http://localhost:3000/up')
  })

  it('includes worker service with sidekiq command', () => {
    expect(content).toContain('command: bundle exec sidekiq')
  })

  it('includes volume definition', () => {
    expect(content).toContain('postgres_data:')
  })

  it('uses DATABASE_URL pointing to postgres service', () => {
    expect(content).toContain('DATABASE_URL: postgres://postgres@postgres:5432/spree_production')
  })

  it('includes redis service and REDIS_URL', () => {
    expect(content).toContain('redis:7-alpine')
    expect(content).toContain('REDIS_URL: redis://redis:6379/0')
  })

  it('includes mailpit service for local email', () => {
    expect(content).toContain('axllent/mailpit')
    expect(content).toContain('SMTP_HOST: mailpit')
  })

  it('disables SSL for local dev', () => {
    expect(content).toContain('RAILS_FORCE_SSL: "false"')
    expect(content).toContain('RAILS_ASSUME_SSL: "false"')
  })

  it('loads env_file', () => {
    expect(content).toContain('env_file: .env')
  })

  it('uses SPREE_PORT variable for port mapping', () => {
    expect(content).toContain('${SPREE_PORT:-3000}:3000')
  })

  it('includes SECRET_KEY_BASE from env', () => {
    expect(content).toContain('SECRET_KEY_BASE: ${SECRET_KEY_BASE}')
  })
})

describe('dockerComposeDevContent', () => {
  const content = dockerComposeDevContent()

  it('uses build context instead of image', () => {
    expect(content).toContain('context: ./backend')
    expect(content).toContain('dockerfile: Dockerfile')
    expect(content).not.toContain('ghcr.io/spree/spree')
  })

  it('has same services as production compose', () => {
    expect(content).toContain('postgres:18-alpine')
    expect(content).toContain('redis:7-alpine')
    expect(content).toContain('axllent/mailpit')
    expect(content).toContain('command: bundle exec sidekiq')
  })
})

describe('envContent', () => {
  it('includes the provided secret key', () => {
    const content = envContent('my-secret-123', 3000)
    expect(content).toContain('SECRET_KEY_BASE=my-secret-123')
  })

  it('includes SPREE_PORT', () => {
    const content = envContent('any', 3000)
    expect(content).toContain('SPREE_PORT=3000')
  })

  it('uses custom port value', () => {
    const content = envContent('any', 4567)
    expect(content).toContain('SPREE_PORT=4567')
  })
})

describe('storefrontEnvContent', () => {
  it('includes placeholder when no key provided', () => {
    const content = storefrontEnvContent(3000)
    expect(content).toContain('pk_REPLACE_ME_AFTER_DOCKER_START')
  })

  it('includes real key when provided', () => {
    const content = storefrontEnvContent(3000, 'pk_test123')
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_test123')
  })

  it('includes API URL with given port', () => {
    const content = storefrontEnvContent(3000)
    expect(content).toContain('SPREE_API_URL=http://localhost:3000')
  })

  it('uses custom port in API URL', () => {
    const content = storefrontEnvContent(4567)
    expect(content).toContain('SPREE_API_URL=http://localhost:4567')
  })
})

describe('rootPackageJsonContent', () => {
  it('returns valid JSON', () => {
    const content = rootPackageJsonContent('my-store')
    expect(() => JSON.parse(content)).not.toThrow()
  })

  it('sets the project name', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.name).toBe('my-store')
  })

  it('includes convenience scripts using spree cli', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.scripts.dev).toBe('spree dev')
    expect(pkg.scripts.update).toBe('spree update')
    expect(pkg.scripts.eject).toBe('spree eject')
    expect(pkg.scripts.logs).toBe('spree logs')
    expect(pkg.scripts.console).toBe('spree console')
    expect(pkg.scripts.down).toContain('docker compose')
  })

  it('includes @spree/cli as a dependency', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.dependencies['@spree/cli']).toBeDefined()
  })

  it('is marked private', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.private).toBe(true)
  })
})

describe('readmeContent', () => {
  it('includes the project name as heading', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('# my-store')
  })

  it('includes admin credentials', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('spree@example.com')
    expect(content).toContain('spree123')
  })

  it('includes storefront section', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('storefront')
    expect(content).toContain('npm run dev')
  })

  it('includes eject instructions', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('spree eject')
    expect(content).toContain('backend/')
  })

  it('uses spree cli commands', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('`spree dev`')
    expect(content).toContain('`spree stop`')
    expect(content).toContain('`spree eject`')
    expect(content).toContain('`spree logs`')
    expect(content).toContain('`spree console`')
    expect(content).toContain('`spree update`')
    expect(content).toContain('`spree user create`')
    expect(content).toContain('`spree api-key create`')
  })

  it('uses custom port in URLs', () => {
    const content = readmeContent('my-store', true, 4567)
    expect(content).toContain('http://localhost:4567/admin')
    expect(content).toContain('http://localhost:4567/api/v3/store')
  })
})

describe('gitignoreContent', () => {
  const content = gitignoreContent()

  it('ignores node_modules', () => {
    expect(content).toContain('node_modules')
  })

  it('ignores .env', () => {
    expect(content).toContain('.env')
  })
})
