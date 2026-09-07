import { Body, Button, Container, Head, Html, Link, Preview, Section, Text } from '@react-email/components';
import * as React from 'react';

interface PasswordResetSuccessEmailProps {
  appName: string;
  supportEmail: string;
  signInUrl?: string;
}

export const PasswordResetSuccessEmail = ({
  appName,
  supportEmail,
  signInUrl = '#',
}: PasswordResetSuccessEmailProps) => (
  <Html lang="en">
    <Head />
    <Preview>Everything is set — your {appName} password has been updated</Preview>
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
        <Section style={heroSection}>
          {/* Checkmark circle */}
          <table cellPadding={0} cellSpacing={0} style={{ margin: '0 auto 40px' }}>
            <tbody>
              <tr>
                <td style={iconCircle}>
                  <Text style={checkmark}>✓</Text>
                </td>
              </tr>
            </tbody>
          </table>

          {/* Heading */}
          <Text style={heading}>Everything is set</Text>

          {/* Subtext */}
          <Text style={subtext}>
            Your password has been successfully updated. You can now use your new credentials to sign in to your
            account.
          </Text>

          {/* CTA button */}
          <table cellPadding={0} cellSpacing={0} style={{ margin: '0 auto' }}>
            <tbody>
              <tr>
                <td style={ctaCell}>
                  <Button href={signInUrl} style={ctaButton}>
                    Sign in to Account
                  </Button>
                </td>
              </tr>
            </tbody>
          </table>
        </Section>

        {/* ── Cards ── */}
        <Section style={cardsSection}>
          {/* Card 1 */}
          <Section style={card}>
            <Text style={cardIcon}>✦</Text>
            <Text style={cardTitle}>Account Security</Text>
            <Text style={cardDesc}>Your account remains protected with industry-standard encryption protocols.</Text>
          </Section>

          {/* Card 2 */}
          <Section style={card}>
            <Text style={cardIcon}>◎</Text>
            <Text style={cardTitle}>Wasn't you?</Text>
            <Text style={cardDesc}>
              If you didn't perform this action, please contact our security team immediately at{' '}
              <Link href={`mailto:${supportEmail}`} style={cardLink}>
                {supportEmail}
              </Link>
            </Text>
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
                  <span style={footerDot}> &nbsp;·&nbsp; </span>
                  <Link href="#" style={footerLink}>
                    Terms of Service
                  </Link>
                  <span style={footerDot}> &nbsp;·&nbsp; </span>
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

PasswordResetSuccessEmail.defaultProps = {
  appName: 'Zentry',
  supportEmail: 'support@zentry.app',
  signInUrl: '#',
};

export default PasswordResetSuccessEmail;

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

// Main container
const main: React.CSSProperties = {
  maxWidth: '672px',
  margin: '0 auto',
  padding: '0 24px',
};

// Hero
const heroSection: React.CSSProperties = {
  paddingTop: '64px',
  paddingBottom: '48px',
  textAlign: 'center',
};

const iconCircle: React.CSSProperties = {
  width: '96px',
  backgroundColor: '#111827',
  // border-radius kept on the <td> — degrades to square in Outlook only
  borderRadius: '50%',
  textAlign: 'center',
  verticalAlign: 'middle',
  // height replaced with padding so Yahoo! Mail renders it correctly
  paddingTop: '24px',
  paddingBottom: '24px',
};

const checkmark: React.CSSProperties = {
  margin: 0,
  fontSize: '40px',
  color: '#ffffff',
  lineHeight: '1.2',
  fontWeight: 200,
  textAlign: 'center',
};

const heading: React.CSSProperties = {
  margin: '0 0 24px',
  fontSize: '44px',
  fontWeight: 800,
  color: '#111827',
  letterSpacing: '-1.5px',
  lineHeight: '1.1',
  textAlign: 'center',
};

const subtext: React.CSSProperties = {
  margin: '0 auto 48px',
  fontSize: '18px',
  color: '#374151',
  lineHeight: '1.7',
  textAlign: 'center',
  maxWidth: '448px',
};

const ctaCell: React.CSSProperties = {
  textAlign: 'center',
};

const ctaButton: React.CSSProperties = {
  display: 'block',
  backgroundColor: '#111827',
  color: '#ffffff',
  fontSize: '15px',
  fontWeight: 600,
  textDecoration: 'none',
  textAlign: 'center',
  borderRadius: '9999px',
  padding: '16px 32px',
  // minWidth replaced with width — minWidth not supported in Outlook
  width: '240px',
  letterSpacing: '0.01em',
};

// Cards
const cardsSection: React.CSSProperties = {
  paddingBottom: '64px',
};

const card: React.CSSProperties = {
  backgroundColor: '#f3f4f6',
  borderRadius: '12px',
  // rgba(0,0,0,0.05) → solid hex equivalent on white background
  border: '1px solid #f2f2f2',
  padding: '24px',
  marginBottom: '16px',
  textAlign: 'left',
};

const cardIcon: React.CSSProperties = {
  margin: '0 0 16px',
  fontSize: '22px',
  color: '#111827',
};

const cardTitle: React.CSSProperties = {
  margin: '0 0 4px',
  fontSize: '14px',
  fontWeight: 700,
  color: '#111827',
};

const cardDesc: React.CSSProperties = {
  margin: 0,
  fontSize: '14px',
  color: '#374151',
  lineHeight: '1.6',
};

const cardLink: React.CSSProperties = {
  color: '#111827',
  textDecoration: 'underline',
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
  padding: '32px 24px',
  textAlign: 'center',
};

const footerBrand: React.CSSProperties = {
  margin: '0 0 16px',
  fontSize: '12px',
  fontWeight: 700,
  color: '#111827',
  letterSpacing: '3px',
  textTransform: 'uppercase',
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
