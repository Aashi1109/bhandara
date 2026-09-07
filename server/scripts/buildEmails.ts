/**
 * Email template build script.
 * Renders TSX templates to HTML using placeholder tokens, then writes
 * plain TypeScript files to src/transactional/generated/.
 *
 * Run: pnpm email:build
 * Regenerate whenever a template changes and commit the output files.
 */

import { render } from '@react-email/render';
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import * as React from 'react';
import { PasswordResetOTPEmail } from '../src/features/email/templates/PasswordResetOTPEmail';
import { PasswordResetSuccessEmail } from '../src/features/email/templates/PasswordResetSuccessEmail';

const OUT_DIR = join(__dirname, '../src/features/email/templates/generated');

const P = {
  APP_NAME: '__APP_NAME__',
  SUPPORT_EMAIL: '__SUPPORT_EMAIL__',
  SIGN_IN_URL: '__SIGN_IN_URL__',
  DIGITS: ['__D0__', '__D1__', '__D2__', '__D3__', '__D4__', '__D5__'],
} as const;

async function buildOTPEmail() {
  const html = await render(
    React.createElement(PasswordResetOTPEmail, {
      appName: P.APP_NAME,
      _digits: [...P.DIGITS],
    }),
  );

  const content = `// AUTO-GENERATED — do not edit. Run \`pnpm email:build\` to regenerate.

const BASE = ${JSON.stringify(html)};

export const renderPasswordResetOTPEmail = (appName: string, otp: string): string => {
  const d = (otp ?? '------').padEnd(6, '-').split('');
  return BASE
    .replaceAll(${JSON.stringify(P.APP_NAME)}, appName)
    .replace(${JSON.stringify(P.DIGITS[0])}, d[0])
    .replace(${JSON.stringify(P.DIGITS[1])}, d[1])
    .replace(${JSON.stringify(P.DIGITS[2])}, d[2])
    .replace(${JSON.stringify(P.DIGITS[3])}, d[3])
    .replace(${JSON.stringify(P.DIGITS[4])}, d[4])
    .replace(${JSON.stringify(P.DIGITS[5])}, d[5]);
};
`;

  writeFileSync(join(OUT_DIR, 'passwordResetOTPEmail.ts'), content, 'utf8');
  console.log('✓ generated/passwordResetOTPEmail.ts');
}

async function buildSuccessEmail() {
  const html = await render(
    React.createElement(PasswordResetSuccessEmail, {
      appName: P.APP_NAME,
      supportEmail: P.SUPPORT_EMAIL,
      signInUrl: P.SIGN_IN_URL,
    }),
  );

  const content = `// AUTO-GENERATED — do not edit. Run \`pnpm email:build\` to regenerate.

const BASE = ${JSON.stringify(html)};

export const renderPasswordResetSuccessEmail = (
  appName: string,
  supportEmail: string,
  signInUrl = '#',
): string =>
  BASE
    .replaceAll(${JSON.stringify(P.APP_NAME)}, appName)
    .replaceAll(${JSON.stringify(P.SUPPORT_EMAIL)}, supportEmail)
    .replaceAll(${JSON.stringify(P.SIGN_IN_URL)}, signInUrl);
`;

  writeFileSync(join(OUT_DIR, 'passwordResetSuccessEmail.ts'), content, 'utf8');
  console.log('✓ generated/passwordResetSuccessEmail.ts');
}

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  await Promise.all([buildOTPEmail(), buildSuccessEmail()]);
  console.log('Email templates compiled successfully.');
}

main().catch((err) => {
  console.error('Email build failed:', err);
  process.exit(1);
});
