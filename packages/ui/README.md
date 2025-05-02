# @nova/ui

UI components used across Nova applications, built with shadcn/ui.

## Overview

This package contains reusable UI components extracted from shadcn/ui. These components are used throughout the Nova dashboard and can be shared with future applications.

## Component List

- Button
- Card
- Dialog
- Input
- Label
- Tabs

## Usage

Install the package in your application:

```bash
# From your app directory
npm install @nova/ui
```

Import components:

```tsx
import { Button, Card } from '@nova/ui';

export default function MyComponent() {
  return (
    <Card>
      <h2>Hello World</h2>
      <Button>Click me</Button>
    </Card>
  );
}
```

## Development

To add a new component:

1. Create a component file in `src/components/`
2. Export it from `src/index.ts`
3. Document usage in this README 