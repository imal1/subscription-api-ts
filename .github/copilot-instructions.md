# Copilot Instructions for Subscription API TypeScript

## Project Overview
This is a TypeScript subscription conversion API service that converts sing-box configurations to Clash format using **mihomo (clash-meta)** core. The project recently migrated from subconverter to mihomo in v2.0.0+ for better protocol support (vless, hysteria2, tuic).

## Architecture & Key Services

### Core Service Pattern
All services follow singleton pattern via `getInstance()`:
- `SubscriptionService` - Main orchestrator for subscription conversion workflow
- `MihomoService` - Handles mihomo binary management and protocol conversion  
- `SingBoxService` - Extracts proxy URLs from sing-box configurations
- `YamlService` - Manages YAML configuration files and validation

### Data Flow
1. **Input**: sing-box configs from `config.singBoxConfigs` array
2. **Extract**: `SingBoxService.getAllConfigUrls()` extracts proxy URLs
3. **Convert**: `MihomoService.convertToClash()` transforms to Clash format
4. **Output**: Files saved to `config.staticDir` (subscription.txt, clash.yaml, raw.txt)

### Configuration System
- Uses hybrid config: `.env` for basic settings + `~/.config/subscription/config.yaml` for advanced
- Config accessed via `yamlService.getFullConfig()` or legacy `config` object
- Key paths: `binaries.mihomo_path`, `app.environment`, `logging.level`



## Environment Command Execution Policy

**Important: AI agents must NOT automatically execute any environment-related commands (such as install, restart, systemd, or service management) in the current development environment!**

- Only output relevant commands (in code blocks) for the developer to copy and debug manually.
- When providing examples, always prefer Linux shell commands.
- Never attempt to auto-run, install, or modify the system environment.

---

## Critical Workflows

### Development Commands
```bash
bun run dev           # Backend development with hot reload
bun run next:dev      # Frontend development (port 3001)
bun run dev:all       # Both backend + frontend concurrently
```

### Build & Deploy
```bash
bun run build:all     # Build backend + frontend together
./scripts/manage.sh   # Unified management script for all operations
sudo ./scripts/manage.sh start  # systemd service management
```

### Diagnostics & Debugging
```bash
bun run diagnose     # Check mihomo health + config validation
./scripts/manage.sh check  # Comprehensive system status
bun run mihomo:version    # Check mihomo binary version
```

## Project-Specific Patterns

### Error Handling in Services
All services use `logger.error()` and throw descriptive errors. Key patterns:
- Check service health before operations: `await mihomoService.checkHealth()`
- Validate inputs extensively (see `SubscriptionService.updateSubscription()`)
- Provide detailed diagnostic info in error responses

### API Response Format
Standard response structure via `ApiResponse` type:
```typescript
{ success: boolean, data?: any, error?: string, timestamp: string }
```

### File Management
- Static files in `config.staticDir` (default: `./data`)
- Automatic backup creation with timestamps in `config.backupDir`
- Use `fs-extra` for all file operations with `await fs.ensureDir()`

### Protocol Support
Post-mihomo migration supports: vless, vmess, trojan, hysteria2, tuic, shadowsocks, wireguard.
Protocol extraction in `SubscriptionService` uses `validProxyProtocols` array.

## Frontend (Next.js) Integration

### SSR Implementation
- Frontend in `/frontend` folder with SSR-enabled Next.js
- API routes proxy to backend: `/api/*` → `http://localhost:3000/api/*`
- SSR demo page shows server-side data fetching patterns
- Use `getServerSideProps` for server-side rendering

### Key Frontend Files
- `frontend/src/pages/api/` - Next.js API routes that proxy to backend
- `frontend/src/components/Dashboard.tsx` - Main UI component
- `frontend/src/pages/ssr-demo.tsx` - SSR demonstration

## Migration Context (v1.x → v2.0+)
Breaking changes from subconverter to mihomo:
- No external service dependency (mihomo auto-downloaded)
- New API endpoints: `/api/diagnose/mihomo` (was `/api/diagnose/subconverter`)
- Enhanced protocol support (vless, hysteria2, tuic now supported)
- Configuration in `config.yaml` instead of just `.env`

## Development Notes
- Use `bun` as package manager and runtime (faster than npm/node)
- systemd service management for production deployments
- Comprehensive management script at `./scripts/manage.sh` for all operations
- Extensive diagnostics and health checking throughout codebase
