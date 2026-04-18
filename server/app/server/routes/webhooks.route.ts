import { onUploadComplete } from '@/src/features/media/controller';
import { asyncHandler } from '../middlewares';
import { type Request, type Response, type NextFunction, Router } from 'express';
import { v2 as cloudinary } from 'cloudinary';
import { config } from '@/src/common';

cloudinary.config({
  cloud_name: config.cloudinary.cloudName,
  api_key: config.cloudinary.apiKey,
  api_secret: config.cloudinary.apiSecret,
});

const verifyCloudinarySignature = (req: Request & { rawBody?: string }, res: Response, next: NextFunction) => {
  const timestamp = req.headers['x-cld-timestamp'] as string | undefined;
  const signature = req.headers['x-cld-signature'] as string | undefined;

  if (!timestamp || !signature) {
    return res.status(401).json({ error: 'Missing webhook signature' });
  }

  try {
    const isValid = cloudinary.utils.verifyNotificationSignature(req.rawBody ?? '', parseInt(timestamp, 10), signature);

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid webhook signature' });
    }
  } catch {
    return res.status(401).json({ error: 'Invalid webhook signature' });
  }

  return next();
};

const router = Router();

/**
 * @openapi
 * /webhooks/on-upload-complete:
 *   post:
 *     tags: [Webhooks]
 *     summary: Receive Cloudinary upload completion notifications
 *     description: Validates the Cloudinary webhook signature and either queues video processing for an existing media record or updates the referenced media metadata from the Cloudinary callback.
 *     security: []
 *     parameters:
 *       - in: header
 *         name: x-cld-timestamp
 *         required: true
 *         schema:
 *           type: string
 *       - in: header
 *         name: x-cld-signature
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               id:
 *                 type: string
 *               mediaId:
 *                 type: string
 *               eventId:
 *                 type: string
 *               secure_url:
 *                 type: string
 *               public_id:
 *                 type: string
 *               asset_id:
 *                 type: string
 *               context:
 *                 type: object
 *                 properties:
 *                   custom:
 *                     type: object
 *                     properties:
 *                       rid:
 *                         type: string
 *     responses:
 *       200:
 *         description: Webhook accepted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   oneOf:
 *                     - type: object
 *                       properties:
 *                         queued:
 *                           type: boolean
 *                     - type: object
 *                       properties:
 *                         updated:
 *                           type: boolean
 *       401:
 *         description: Missing or invalid Cloudinary signature
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *       404:
 *         description: Referenced media record was not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.post('/on-upload-complete', verifyCloudinarySignature, asyncHandler(onUploadComplete));

export default router;
