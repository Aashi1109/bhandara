import {
  uploadFile,
  getSignedUploadUrl,
  deleteFile,
  getMediaById,
  updateMedia,
  getMediaPublicUrl,
  getMediaPublicUrls,
  getPublicSignedUploadUrl,
} from '@/features/media/controller';
import { asyncHandler, sessionParser, userParser, validateRequest } from '@/middlewares';
import { Router } from 'express';
import { mediaUpdateSchema } from '@/features/media/validation';

const router = Router({ mergeParams: true });

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /media/public-urls:
 *   get:
 *     tags: [Media]
 *     summary: Get public URLs for media
 *     responses:
 *       200:
 *         description: Public URLs by media ID
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/public-urls', asyncHandler(getMediaPublicUrls));
/**
 * @openapi
 * /media/upload:
 *   post:
 *     tags: [Media]
 *     summary: Upload file
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Uploaded media
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.post('/upload', asyncHandler(uploadFile));
/**
 * @openapi
 * /media/get-signed-upload-url:
 *   post:
 *     tags: [Media]
 *     summary: Get signed upload URL
 *     responses:
 *       200:
 *         description: Signed upload URL
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.post('/get-signed-upload-url', asyncHandler(getSignedUploadUrl));
/**
 * @openapi
 * /media/get-public-upload-url:
 *   post:
 *     tags: [Media]
 *     summary: Get a public upload URL
 *     responses:
 *       200:
 *         description: Public upload URL
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.post('/get-public-upload-url', asyncHandler(getPublicSignedUploadUrl));
router
  .route('/:mediaId')
  /**
   * @openapi
   * /media/{mediaId}:
   *   delete:
   *     tags: [Media]
   *     summary: Delete media
   *     parameters:
   *       - in: path
   *         name: mediaId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Deleted media
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/ApiEnvelope'
   *   get:
   *     tags: [Media]
   *     summary: Get media by ID
   *     parameters:
   *       - in: path
   *         name: mediaId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Media detail
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Media'
   *                 error:
   *                   nullable: true
   *   patch:
   *     tags: [Media]
   *     summary: Update media
   *     parameters:
   *       - in: path
   *         name: mediaId
   *         required: true
   *         schema:
   *           type: string
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/Media'
   *     responses:
   *       200:
   *         description: Updated media
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Media'
   *                 error:
   *                   nullable: true
   */
  .delete(asyncHandler(deleteFile))
  .get(asyncHandler(getMediaById))
  .patch(validateRequest('MEDIA_UPDATE', mediaUpdateSchema), asyncHandler(updateMedia));

/**
 * @openapi
 * /media/public-url:
 *   post:
 *     tags: [Media]
 *     summary: Get public URL for a media file
 *     responses:
 *       200:
 *         description: Public URL for the requested media
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.post('/public-url', asyncHandler(getMediaPublicUrl));

export default router;
