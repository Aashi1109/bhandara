import { Resend } from 'resend';
import config from '@/config';
import logger from '@/logger';

const resend = new Resend(config.resend.apiKey);

const from = `${config.resend.fromName} <${config.resend.fromEmail}>`;

export const sendPasswordResetOTPEmail = async (to: string, otp: string): Promise<void> => {
  const { error } = await resend.emails.send({
    from,
    to,
    subject: 'Your Zentry password reset code',
    html: buildOTPEmailHtml(otp),
  });

  if (error) {
    logger.error({ msg: 'Failed to send password reset OTP email', error, to });
    throw new Error('Failed to send reset email. Please try again.');
  }
};

const buildOTPEmailHtml = (otp: string): string => `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Reset your Zentry password</title>
</head>
<body style="margin:0;padding:0;background-color:#f3f4f6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.06);">
          <!-- Header -->
          <tr>
            <td style="padding:32px 40px 24px;text-align:center;border-bottom:1px solid #e5e7eb;">
              <p style="margin:0;font-size:22px;font-weight:700;color:#111827;letter-spacing:-0.5px;">Zentry</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 24px;">
              <p style="margin:0 0 8px;font-size:20px;font-weight:700;color:#111827;">Reset your password</p>
              <p style="margin:0 0 32px;font-size:15px;color:#6b7280;line-height:1.6;">
                Use the code below to reset your Zentry password. This code expires in <strong>10 minutes</strong>.
              </p>
              <!-- OTP box -->
              <div style="background:#f3f4f6;border-radius:12px;padding:24px;text-align:center;margin-bottom:32px;">
                <p style="margin:0 0 4px;font-size:12px;font-weight:600;letter-spacing:2px;color:#9ca3af;text-transform:uppercase;">Verification code</p>
                <p style="margin:0;font-size:40px;font-weight:800;letter-spacing:12px;color:#111827;font-variant-numeric:tabular-nums;">${otp}</p>
              </div>
              <p style="margin:0;font-size:13px;color:#9ca3af;line-height:1.6;">
                If you didn't request a password reset, you can safely ignore this email. Your password will not change.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:24px 40px;border-top:1px solid #e5e7eb;">
              <p style="margin:0;font-size:12px;color:#d1d5db;text-align:center;">© ${new Date().getFullYear()} Zentry. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;
