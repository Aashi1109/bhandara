import js from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';
import prettierConfig from 'eslint-config-prettier';
import { defineConfig } from 'eslint/config';

export default defineConfig([
  {
    files: ['**/*.{js,mjs,cjs,ts}'],
    plugins: { js },
    extends: ['js/recommended'],
  },
  {
    files: ['**/*.{js,mjs,cjs,ts}'],
    languageOptions: {
      globals: { ...globals.node, ...globals.es2022 },
    },
  },
  {
    rules: {
      //* Bugs & Safety
      'no-console': 'off',
      'no-undef': 'error',
      semi: ['error', 'always'],
      'semi-spacing': 'error',
      //* Best Practices
      eqeqeq: ['error', 'always'],
      'no-invalid-this': 'error',
      'no-return-assign': 'error',
      'no-unused-expressions': ['error', { allowTernary: true }],
      'no-useless-concat': 'error',
      'no-useless-return': 'error',
      'no-constant-condition': 'warn',
      'no-unused-vars': 'off',
      'no-shadow': 'error',
      'no-throw-literal': 'error',
      'consistent-return': 'off',
      //* Readability
      indent: ['error', 2, { SwitchCase: 1 }],
      'no-mixed-spaces-and-tabs': 'warn',
      'space-before-blocks': 'error',
      'space-in-parens': 'error',
      'space-infix-ops': 'error',
      'space-unary-ops': 'error',
      quotes: ['error', 'single', { avoidEscape: true }],
      'max-len': ['error', { code: 200, ignoreUrls: true, ignoreStrings: true, ignoreTemplateLiterals: true }],
      'max-lines': ['error', { max: 600, skipBlankLines: true, skipComments: true }],
      'keyword-spacing': 'error',
      'multiline-ternary': ['error', 'never'],
      'no-mixed-operators': 'error',
      'no-multiple-empty-lines': ['error', { max: 2, maxEOF: 1 }],
      'no-whitespace-before-property': 'error',
      'nonblock-statement-body-position': 'error',
      'object-property-newline': ['error', { allowAllPropertiesOnSameLine: true }],
      //* ES6+
      'arrow-spacing': 'error',
      'no-confusing-arrow': 'error',
      'no-duplicate-imports': 'error',
      'no-var': 'error',
      'object-shorthand': ['warn', 'always'],
      'prefer-const': 'error',
      'prefer-template': 'warn',
      'prefer-arrow-callback': 'warn',
      'prefer-destructuring': 'off',
    },
  },
  tseslint.configs.recommended,
  {
    files: ['**/*.ts'],
    rules: {
      '@typescript-eslint/no-unused-vars': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
      '@typescript-eslint/consistent-type-imports': ['warn', { prefer: 'type-imports' }],
      '@typescript-eslint/no-floating-promises': 'off',
      '@typescript-eslint/no-require-imports': 'warn',
    },
  },
  prettierConfig,
  {
    ignores: ['dist/**', 'node_modules/**', 'coverage/**', '*.config.{js,mjs,cjs}'],
  },
]);
