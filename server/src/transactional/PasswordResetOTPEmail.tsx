import {
  Body,
  Button,
  Column,
  Container,
  Head,
  Hr,
  Html,
  Link,
  Preview,
  Row,
  Section,
  Text,
} from '@react-email/components';
import * as React from 'react';

interface PasswordResetOTPEmailProps {
  appName: string;
  otp?: string;
  /** Used only by the build script to inject placeholder tokens per digit cell */
  _digits?: string[];
}

export const PasswordResetOTPEmail = ({ appName, otp, _digits }: PasswordResetOTPEmailProps) => {
  const digits = _digits ?? (otp ?? '------').split('');

  return (
    <Html lang="en">
      <Head />
      <Preview>Your {appName} verification code</Preview>
      <Body style={body}>
        {/* ── Header ── */}
        <Section style={headerWrap}>
          <table width="100%" cellPadding={0} cellSpacing={0}>
            <tbody>
              <tr>
                <td style={headerInner}>
                  <Text style={logo}>{appName}</Text>
                </td>
              </tr>
            </tbody>
          </table>
        </Section>

        {/* ── Main ── */}
        <Container style={main}>
          <Section style={mainInner}>
            {/* Lock icon circle */}
            <table cellPadding={0} cellSpacing={0} style={{ margin: '0 auto 32px' }}>
              <tbody>
                <tr>
                  <td style={iconCircle}>
                    <Text style={lockIcon}>🔒</Text>
                  </td>
                </tr>
              </tbody>
            </table>

            {/* Heading */}
            <Text style={heading}>Verification Code</Text>

            {/* Subtext */}
            <Text style={subtext}>Please use the following 6-digit code to complete your authentication process.</Text>

            {/* ── OTP cells ── */}
            <Section style={otpSection}>
              <table cellPadding={0} cellSpacing={0} style={{ margin: '0 auto' }}>
                <tbody>
                  <tr>
                    {digits.map((digit, i) => (
                      <td key={i} style={i < digits.length - 1 ? otpCellWithGap : otpCell}>
                        <Text style={otpDigit}>{digit}</Text>
                      </td>
                    ))}
                  </tr>
                </tbody>
              </table>
            </Section>

            {/* Expiry */}
            <Text style={expiryText}>
              THIS CODE EXPIRES IN <span style={expiryHighlight}>10 MINUTES</span>
            </Text>

            {/* "Enter Code Now" pill button */}
            <table cellPadding={0} cellSpacing={0} style={{ margin: '16px auto 0' }}>
              <tbody>
                <tr>
                  <td>
                    <Button href="#" style={enterButton}>
                      Enter Code Now
                    </Button>
                  </td>
                </tr>
              </tbody>
            </table>

            {/* Security notice */}
            <Section style={securityBox}>
              <table cellPadding={0} cellSpacing={0} width="100%">
                <tbody>
                  <tr>
                    <td style={securityIconCell}>
                      <Text style={securityIcon}>ℹ️</Text>
                    </td>
                    <td style={securityTextCell}>
                      <Text style={securityText}>
                        If you did not request this verification code, please ignore this email or contact security
                        support immediately. Your account safety is our priority.
                      </Text>
                    </td>
                  </tr>
                </tbody>
              </table>
            </Section>
          </Section>
        </Container>

        {/* ── Footer ── */}
        <Section style={footerWrap}>
          <table width="100%" cellPadding={0} cellSpacing={0}>
            <tbody>
              <tr>
                <td style={footerInner}>
                  <Text style={footerBrand}>{appName.toUpperCase()}</Text>
                  <Text style={footerLinksRow}>
                    <Link href="#" style={footerLink}>
                      Privacy Policy
                    </Link>
                    <span style={footerDot}>&nbsp;·&nbsp;</span>
                    <Link href="#" style={footerLink}>
                      Terms of Service
                    </Link>
                    <span style={footerDot}>&nbsp;·&nbsp;</span>
                    <Link href="#" style={footerLink}>
                      Support
                    </Link>
                  </Text>
                  <Text style={footerCopy}>
                    © {new Date().getFullYear()} {appName}. All rights reserved.
                  </Text>
                </td>
              </tr>
            </tbody>
          </table>
        </Section>
      </Body>
    </Html>
  );
};

PasswordResetOTPEmail.defaultProps = {
  appName: 'Zentry',
  otp: '824917',
};

export default PasswordResetOTPEmail;

// ─── Styles ──────────────────────────────────────────────────────────────────

const body: React.CSSProperties = {
  margin: 0,
  padding: 0,
  backgroundColor: '#ffffff',
  fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
};

// Header
const headerWrap: React.CSSProperties = {
  width: '100%',
  borderBottom: '1px solid #f3f4f6',
  backgroundColor: '#ffffff',
};

const headerInner: React.CSSProperties = {
  maxWidth: '672px',
  margin: '0 auto',
  padding: '16px 24px',
};

const logo: React.CSSProperties = {
  margin: 0,
  fontSize: '20px',
  fontWeight: 700,
  color: '#111827',
  letterSpacing: '-0.5px',
};

// Main
const main: React.CSSProperties = {
  maxWidth: '448px',
  margin: '0 auto',
  padding: '0 24px',
};

const mainInner: React.CSSProperties = {
  paddingTop: '48px',
  paddingBottom: '48px',
  textAlign: 'center',
};

// Lock icon
const iconCircle: React.CSSProperties = {
  width: '96px',
  height: '96px',
  backgroundColor: '#000000',
  borderRadius: '50%',
  textAlign: 'center',
  verticalAlign: 'middle',
};

const lockIcon: React.CSSProperties = {
  margin: 0,
  fontSize: '36px',
  lineHeight: '96px',
  textAlign: 'center',
};

// Heading
const heading: React.CSSProperties = {
  margin: '0 0 12px',
  fontSize: '36px',
  fontWeight: 800,
  color: '#111827',
  letterSpacing: '-1px',
  lineHeight: '1.1',
  textAlign: 'center',
};

// Subtext
const subtext: React.CSSProperties = {
  margin: '0 auto 48px',
  fontSize: '14px',
  color: '#6b7280',
  lineHeight: '1.6',
  textAlign: 'center',
  maxWidth: '280px',
};

// OTP section — border top & bottom, py-10 (40px), white bg
const otpSection: React.CSSProperties = {
  borderTop: '1px solid #e5e7eb',
  borderBottom: '1px solid #e5e7eb',
  backgroundColor: '#ffffff',
  padding: '40px 0',
  marginBottom: '32px',
};

// Individual digit cell — w-12 h-16 (48×64px), border-2 border-primary, rounded-lg (16px)
const otpCell: React.CSSProperties = {
  width: '48px',
  height: '64px',
  border: '2px solid #111827',
  borderRadius: '16px',
  backgroundColor: '#ffffff',
  textAlign: 'center',
  verticalAlign: 'middle',
};

const otpCellWithGap: React.CSSProperties = {
  ...otpCell,
  paddingRight: '12px',
};

const otpDigit: React.CSSProperties = {
  margin: 0,
  fontSize: '30px',
  fontWeight: 800,
  color: '#111827',
  lineHeight: '60px',
  fontVariantNumeric: 'tabular-nums',
};

// Expiry text
const expiryText: React.CSSProperties = {
  margin: '0 0 4px',
  fontSize: '12px',
  fontWeight: 500,
  color: '#6b7280',
  letterSpacing: '0.05em',
  textTransform: 'uppercase',
  textAlign: 'center',
};

const expiryHighlight: React.CSSProperties = {
  color: '#111827',
  fontWeight: 700,
};

// "Enter Code Now" pill button
const enterButton: React.CSSProperties = {
  display: 'inline-block',
  backgroundColor: '#111827',
  color: '#ffffff',
  fontSize: '14px',
  fontWeight: 700,
  textDecoration: 'none',
  textAlign: 'center',
  borderRadius: '9999px',
  padding: '12px 32px',
  letterSpacing: '-0.01em',
};

// Security notice
const securityBox: React.CSSProperties = {
  backgroundColor: '#f3f4f6',
  borderRadius: '8px',
  padding: '16px',
  marginTop: '32px',
  textAlign: 'left',
};

const securityIconCell: React.CSSProperties = {
  verticalAlign: 'top',
  paddingRight: '12px',
  width: '24px',
};

const securityIcon: React.CSSProperties = {
  margin: 0,
  fontSize: '16px',
  lineHeight: '1',
};

const securityTextCell: React.CSSProperties = {
  verticalAlign: 'top',
};

const securityText: React.CSSProperties = {
  margin: 0,
  fontSize: '11px',
  color: '#374151',
  lineHeight: '1.6',
};

// Footer
const footerWrap: React.CSSProperties = {
  width: '100%',
  backgroundColor: '#f9fafb',
  borderTop: '1px solid #e5e7eb',
};

const footerInner: React.CSSProperties = {
  maxWidth: '672px',
  margin: '0 auto',
  padding: '48px 32px 32px',
  textAlign: 'center',
};

const footerBrand: React.CSSProperties = {
  margin: '0 0 16px',
  fontSize: '14px',
  fontWeight: 700,
  color: '#111827',
  letterSpacing: '3px',
};

const footerLinksRow: React.CSSProperties = {
  margin: '0 0 16px',
  fontSize: '12px',
  color: '#9ca3af',
  textAlign: 'center',
};

const footerLink: React.CSSProperties = {
  color: '#9ca3af',
  textDecoration: 'none',
  fontSize: '12px',
};

const footerDot: React.CSSProperties = {
  color: '#d1d5db',
};

const footerCopy: React.CSSProperties = {
  margin: 0,
  fontSize: '12px',
  color: '#9ca3af',
  lineHeight: '1.6',
};
