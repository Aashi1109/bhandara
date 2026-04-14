import { Resend } from 'resend';
import config from '@/config';
import logger from '@/logger';
import { renderPasswordResetOTPEmail } from '@/transactional/generated/passwordResetOTPEmail';
import { renderPasswordResetSuccessEmail } from '@/transactional/generated/passwordResetSuccessEmail';

const resend = new Resend(config.resend.apiKey);

const appName = config.resend.fromName;
const supportEmail = config.resend.fromEmail.replace('noreply', 'support');
const from = `${appName} <${config.resend.fromEmail}>`;

export const sendPasswordResetOTPEmail = async (to: string, otp: string): Promise<void> => {
  const { error } = await resend.emails.send({
    from,
    to,
    subject: `Your ${appName} password reset code`,
    html: renderPasswordResetOTPEmail(appName, otp),
  });

  if (error) {
    logger.error({ msg: 'Failed to send password reset OTP email', error, to });
    throw new Error('Failed to send reset email. Please try again.');
  }
};

export const sendPasswordResetSuccessEmail = async (to: string): Promise<void> => {
  const { error } = await resend.emails.send({
    from,
    to,
    subject: `Your ${appName} password has been updated`,
    html: renderPasswordResetSuccessEmail(appName, supportEmail),
  });

  if (error) {
    logger.error({ msg: 'Failed to send password reset success email', error, to });
    throw new Error('Failed to send confirmation email.');
  }
};
