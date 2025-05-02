# Contributing to Nova Dashboard

Thank you for your interest in contributing to the Nova Dashboard monorepo! This document outlines the process for contributing to the project.

## Development Environment

### Prerequisites

- Node.js 18+
- npm 8+
- Git

### Getting Started

1. Fork the repository
2. Clone your fork

   ```bash
   git clone https://github.com/evca-team/nova.git
   cd nova
   ```

3. Install dependencies

   ```bash
   npm install
   ```

4. Start the development server

   ```bash
   npm run dev
   ```

## Monorepo Structure

Our project follows a monorepo structure:

```
nova/
├── apps/
│   └── dashboard/     # Next.js dashboard application
├── packages/
│   ├── ui/            # Shared UI components
│   ├── db/            # Database client & schemas
│   ├── config/        # Shared configurations
│   ├── billing/       # Billing integration (optional)
│   └── gallery/       # Media gallery features (optional)
└── ...
```

## Development Workflow

1. **Create a branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**

   - Follow the code style guidelines
   - Keep each package focused on a single responsibility
   - Reuse shared packages whenever possible

3. **Test your changes**

   ```bash
   npm run lint
   npm run type-check
   npm run build
   ```

4. **Commit your changes**

   ```bash
   git commit -m "feat: add new feature"
   ```

   Use conventional commit messages:

   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `chore:` for maintenance tasks
   - `refactor:` for code refactoring
   - `test:` for adding tests

5. **Push your changes**

   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a pull request**
   - Use the provided PR template
   - Link to any related issues
   - Be descriptive about what has changed

## Code Standards

- **TypeScript**: Use strict type checking
- **Linting**: Follow ESLint rules
- **Formatting**: Use Prettier
- **Tests**: Add tests for new functionality
- **Documentation**: Update docs for new features or changes

## Package Development Guidelines

1. **Package-First Approach**

   - Add new functionality to appropriate packages
   - Prefer creating reusable packages over app-specific code

2. **Versioning**

   - Follow semantic versioning for packages
   - Document breaking changes

3. **Dependencies**
   - Keep dependencies minimal and up-to-date
   - Use `peerDependencies` appropriately

## Need Help?

- Check the existing issues
- Create a new issue with the appropriate template
- Discuss major changes before implementation
