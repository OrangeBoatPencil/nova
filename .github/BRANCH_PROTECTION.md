# Branch Protection Setup

## Main Branch Protection

To ensure code quality and prevent unintended changes, the `main` branch should be protected with the following settings:

1. Go to GitHub repository settings → Branches → Add rule
2. Configure with:
   - Branch name pattern: `main`
   - Require a pull request before merging
   - Require approvals (1+)
   - Require status checks to pass:
     - `lint`
     - `type-check`
     - `check-format`
     - `build`
   - Require branches to be up to date before merging
   - Include administrators

## Required GitHub Secrets for CI/CD

For CI/CD workflows to function properly, the following secrets must be set in the repository:

- `VERCEL_TOKEN`: API token from Vercel
- `VERCEL_ORG_ID`: Organization ID from Vercel
- `VERCEL_PROJECT_ID`: Project ID from Vercel

### How to get these values:

1. **VERCEL_TOKEN**

   - Go to [Vercel Account Settings](https://vercel.com/account/tokens)
   - Create a new token with appropriate permissions

2. **VERCEL_ORG_ID & VERCEL_PROJECT_ID**
   - Run `vercel link` in the project directory
   - Check `.vercel/project.json` for these values

## Team Setup

Create the following teams in the GitHub organization:

- `maintainers`: Admin access to repository
- `ui-team`: Manages UI components
- `db-team`: Manages database code
- `billing-team`: Manages Stripe integration
- `admin`: Manages repository configuration
