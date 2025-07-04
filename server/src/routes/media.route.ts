import {
  uploadFile,
  getSignedUploadUrl,
  deleteFile,
  getMediaById,
  updateMedia,
  getMediaPublicUrl,
  getMediaPublicUrls,
  getPublicSignedUploadUrl,
} from "@features/media/controller";
/**
 * @openapi
 * components:
 *   schemas:
 *     Media:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         url:
 *           type: string
 */
import { asyncHandler, sessionParser, userParser } from "@middlewares";
import { Router } from "express";

const router = Router({ mergeParams: true });

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /media/public-urls:
 *   get:
 *     tags: [Media]
 *     summary: Get public URLs for media
 */
router.get("/public-urls", asyncHandler(getMediaPublicUrls));
/**
 * @openapi
 * /media/upload:
 *   post:
 *     tags: [Media]
 *     summary: Upload file
 */
router.post("/upload", asyncHandler(uploadFile));
/**
 * @openapi
 * /media/get-signed-upload-url:
 *   post:
 *     tags: [Media]
 *     summary: Get signed upload URL
 */
router.post("/get-signed-upload-url", asyncHandler(getSignedUploadUrl));
router.post(
  "/get-public-upload-url",
  asyncHandler(getPublicSignedUploadUrl)
);
router
  .route("/:mediaId")
  /**
   * @openapi
   * /media/{mediaId}:
   *   delete:
   *     tags: [Media]
   *     summary: Delete media
   *   get:
   *     tags: [Media]
   *     summary: Get media by ID
   *   patch:
   *     tags: [Media]
   *     summary: Update media
   */
  .delete(asyncHandler(deleteFile))
  .get(asyncHandler(getMediaById))
  .patch(asyncHandler(updateMedia));

/**
 * @openapi
 * /media/public-url:
 *   post:
 *     tags: [Media]
 *     summary: Get public URL for a media file
 */
router.post("/public-url", asyncHandler(getMediaPublicUrl));

export default router;
