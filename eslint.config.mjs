import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";
import js from "@eslint/js";
import tsEslint from "typescript-eslint";
import reactRecommended from "eslint-plugin-react/configs/recommended.js";
import reactHooks from "eslint-plugin-react-hooks";
// import nextPlugin from "@next/eslint-plugin-next"; // Will use compat.extends for Next for now
import prettierConfig from "eslint-config-prettier";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

export default tsEslint.config(
  js.configs.recommended,

  ...tsEslint.configs.recommended,

  reactRecommended,

  ...compat.extends("next/core-web-vitals"),

  prettierConfig,

  {
    files: ["**/*.{js,jsx,ts,tsx}"],
    plugins: {
      "react-hooks": reactHooks,
      // "@next/next": nextPlugin, // Removed for now, relying on compat.extends
    },
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: __dirname,
        sourceType: "module",
        ecmaVersion: "latest",
      },
      globals: {
        browser: true,
        node: true,
      },
    },
    settings: {
      react: {
        version: "detect",
      },
      // Settings for next/core-web-vitals might be inherited via compat.extends
      // If specific Next settings are needed, they might need separate config object
      // next: {
      //     rootDir: ["."], 
      // },
    },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",

      "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
      "@typescript-eslint/explicit-module-boundary-types": "off",
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-non-null-assertion": "warn",
      "react/react-in-jsx-scope": "off",
      "react/prop-types": "off",

      "@next/next/no-html-link-for-pages": "off",
    },
  },

  // Configuration specifically for *.js files (like config files)
  {
    files: ["**/*.js"],
    rules: {
      // Allow require() in JS config files
      "@typescript-eslint/no-require-imports": "off",
      "@typescript-eslint/no-var-requires": "off", // Also allow var requires if needed
    },
  },

  {
    ignores: [
      ".next/",
      ".turbo/",
      "node_modules/",
      "dist/",
      "coverage/",
      // Keep ignoring config files themselves from *other* rules
      // "*.config.js",
      // "*.config.mjs",
      "*.setup.ts",
      "public/",
      "supabase/migrations/",
      "test-results/",
      "playwright-report/",
      ".swc/",
      ".vscode/",
      ".husky/",
    ],
  }
);
