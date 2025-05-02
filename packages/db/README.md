# @nova/db

Database client and types for Nova applications, using Supabase.

## Overview

This package provides:

1. A pre-configured Supabase client for data access
2. TypeScript interfaces for database entities
3. Helper functions for authentication and data fetching

## Entities

The package includes TypeScript interfaces for:

- **Member** - User profiles
- **Team** - Organization or groups
- **MemberRole** - User roles within teams
- **ActivityLog** - Audit trail of user actions

## Usage

Install the package in your application:

```bash
# From your app directory
npm install @nova/db
```

### Client-side usage:

```tsx
import { supabase } from '@nova/db';

// Fetch teams
const { data, error } = await supabase
  .from('teams')
  .select('*');
```

### Server-side usage:

```tsx
import { createServerSupabaseClient } from '@nova/db';
import { cookies } from 'next/headers';

export async function getData() {
  const supabase = createServerSupabaseClient(cookies());
  
  const { data } = await supabase
    .from('members')
    .select('*');
    
  return data;
}
```

## Development

To add new database types:

1. Define new interfaces in `src/types.ts`
2. Export them from `src/index.ts` 