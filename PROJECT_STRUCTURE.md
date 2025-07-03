# Project Structure

This document outlines the directory structure and organization of the Subscription API TypeScript project.

## Directory Tree

```
subscription-api-ts/
├── src/                              # Source code
│   ├── types/                        # TypeScript type definitions
│   │   └── index.ts
│   ├── config/                       # Configuration files
│   │   └── index.ts
│   ├── utils/                        # Utility functions
│   │   └── logger.ts
│   ├── services/                     # Business logic services
│   │   ├── singBoxService.ts
│   │   ├── subconverterService.ts
│   │   └── subscriptionService.ts
│   ├── controllers/                  # API controllers
│   │   └── subscriptionController.ts
│   ├── routes/                       # API routes
│   │   └── index.ts
│   ├── app.ts                        # Express app setup
│   └── index.ts                      # Application entry point
├── config/                           # System configuration files
│   ├── nginx.conf.template           # Nginx template
│   └── subscription-api-ts.service.template  # SystemD template
├── scripts/                          # Automation scripts
│   ├── install.sh                    # Installation script
│   └── deploy.sh                     # Deployment script
├── etc/                              # System configuration examples
│   ├── nginx/
│   │   └── sites-available/
│   │       ├── subscription-api
│   │       └── subscription-api-ts
│   └── systemd/
│       └── system/
│           ├── subscription-api.service
│           ├── subscription-api-node.service
│           ├── subscription-api-ts-compiled.service
│           └── subconverter.service
├── opt/                              # Legacy/alternative implementations
│   └── subscription-api/
│       ├── src/                      # TypeScript source (mirror)
│       ├── app.js                    # JavaScript version
│       ├── subscription_api.py       # Python version
│       ├── gunicorn_config.py        # Gunicorn configuration
│       ├── package.json              # Node.js package config
│       └── tsconfig.json             # TypeScript config
├── data/                             # Data directory (runtime)
│   └── backup/                       # Backup files
├── logs/                             # Log files (runtime)
├── dist/                             # Compiled output (generated)
├── node_modules/                     # Dependencies (generated)
├── .env                              # Environment variables (local)
├── .env.example                      # Environment template
├── .gitignore                        # Git ignore rules
├── package.json                      # Node.js package definition
├── package-lock.json                # Dependency lock file
├── bun.lock                          # Bun package manager lock
├── tsconfig.json                     # TypeScript configuration
├── README.md                         # Project documentation
├── LICENSE                           # License file
├── ENVIRONMENT_VARIABLES.md          # Environment variables docs
└── PROJECT_STRUCTURE.md              # This file
```

## Key Directories

### `/src`
Contains the main TypeScript source code organized by functionality:
- **types**: TypeScript interfaces and type definitions
- **config**: Application configuration management
- **utils**: Shared utility functions (logging, etc.)
- **services**: Core business logic for subscription handling
- **controllers**: HTTP request handlers
- **routes**: API route definitions

### `/config`
System configuration templates (not committed files):
- Nginx configuration template for reverse proxy
- SystemD service template for Linux deployment
- Templates support environment variable substitution
- Generated files are in .gitignore

### `/scripts`
Automation and deployment scripts:
- Installation and setup scripts
- Diagnostic and troubleshooting tools
- Configuration generation utilities
- Service management helpers

### `/etc`
Example system configuration files showing proper placement in Linux systems.

### `/opt`
Legacy implementations in different languages (JavaScript, Python) for compatibility.

## File Naming Conventions

- TypeScript files: `camelCase.ts`
- Configuration files: `kebab-case.conf` or `kebab-case.json`
- Shell scripts: `kebab-case.sh`
- Documentation: `UPPER_CASE.md`
- Service files: `kebab-case.service`

## Build Artifacts

- `dist/`: Compiled JavaScript output
- `node_modules/`: Bun dependencies
- `data/`: Runtime data storage
- `logs/`: Application logs

These directories are automatically created during build or runtime.