# Contributing to Nova Dashboard

Thank you for considering contributing to Nova Dashboard! This document outlines the process for contributing to this monorepo project.

## Table of Contents

- [Development Philosophy](#development-philosophy)
- [Getting Started](#getting-started)
- [Git Workflow](#git-workflow)
- [Monorepo Structure](#monorepo-structure)
- [Feature Development Process](#feature-development-process)
- [Code Style & Quality](#code-style--quality)
- [Pull Request Process](#pull-request-process)
- [Deployment Process](#deployment-process)

## Development Philosophy

Nova Dashboard follows these core principles:

1. **Package-First Development**: Create reusable code in packages before integrating into apps
2. **Single Source of Truth**: No duplicate implementations across the codebase
3. **Clear Boundaries**: Explicit dependencies between packages
4. **Consistent Patterns**: Follow established patterns for each package type
5. **Self-Documenting**: Each package includes usage documentation

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- Git

### Setup

1. Clone the repository

   ```bash
   git clone https://github.com/OrangeBoatPencil/nova.git
   cd nova
   ```

2. Install dependencies

   ```bash
   npm install
   ```

3. Set up environment variables

   ```bash
   # Pull from Vercel (recommended)
   vercel env pull apps/dashboard/.env.local

   # Or create manually
   cp apps/dashboard/.env.example apps/dashboard/.env.local
   # Then edit .env.local with your values
   ```

4. Start the development server
   ```bash
   npm run dev
   ```

## Git Workflow

### Branch Naming

- `feature/short-description` - For new features
- `fix/issue-description` - For bug fixes
- `refactor/component-name` - For code improvements
- `docs/update-area` - For documentation updates

### Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat: add new button component` - For features
- `fix: resolve auth redirect issue` - For bug fixes
- `refactor: improve type definitions` - For code improvements
- `docs: update README` - For documentation
- `chore: update dependencies` - For maintenance tasks

## Monorepo Structure

```
/
├── apps/                  # Applications
│   └── dashboard/         # Member dashboard (Next.js)
├── packages/              # Shared packages
│   ├── ui/                # UI components
│   ├── db/                # Database client and types
│   ├── billing/           # Stripe integration
│   ├── gallery/           # Media utilities
│   └── config/            # Shared configs
└── turbo.json             # Turborepo configuration
```

### Package Responsibilities

- **apps/dashboard**: Main Next.js application (imports from packages)
- **packages/ui**: Reusable UI components built with shadcn/ui
- **packages/db**: Database client, types, and data access utilities
- **packages/billing**: Stripe integration for subscriptions
- **packages/gallery**: Media handling and search utilities
- **packages/config**: Shared configuration (ESLint, TypeScript, etc.)

## Feature Development Process

1. **Create an Issue**: Document the feature, including which package it belongs to
2. **Create a Branch**: Following the branch naming convention
3. **Package-First Development**:
   - Identify which package the code belongs in
   - Implement core functionality in that package
   - Document usage in the package README
4. **App Integration**:
   - Import functionality from packages into apps
   - Complete the feature implementation
5. **Submit a PR**: Following the PR template

## Code Style & Quality

### Linting and Formatting

- **Prettier**: For code formatting
- **ESLint**: For code quality
- **TypeScript**: Strict mode enabled

Run checks before committing:

```bash
npm run lint      # Run linting
npm run format    # Format code with Prettier
```

### Component Guidelines

1. **UI Components**:

   - Each component should be well-typed
   - Include clear props documentation
   - Export from package index.ts
   - Document in README.md with examples

2. **Database Utilities**:
   - Strong TypeScript interfaces
   - Error handling for database operations
   - Clear documentation for complex queries

## Pull Request Process

1. **Create a PR**: Use the PR template
2. **Describe Changes**: Clearly document what changes were made
3. **Self-Review**: Go through the PR checklist yourself first
4. **Request Review**: Assign to appropriate reviewers
5. **Address Feedback**: Make requested changes promptly
6. **Merge**: Once approved, merge your PR

## Deployment Process

1. **Continuous Integration**: GitHub Actions run on every PR
2. **Preview Deployments**: Automatically deployed from PRs
3. **Staging Deployment**: Merged code is deployed to staging
4. **Production Deployment**: Manual promotion from staging after testing

### Environment Variables

- Development: Local .env.local files
- Preview/Staging/Production: Environment variables in Vercel

### Debugging Deployments

If a deployment fails:

1. Check Vercel logs
2. Verify environment variables
3. Test locally with production settings
4. Reach out to the team for help

---

Thank you for contributing to Nova Dashboard! If you have any questions, please reach out to the team.
