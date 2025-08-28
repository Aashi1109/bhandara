/**
 * @openapi
 * components:
 *   schemas:
 *     Tag:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         value:
 *           type: string
 */
import { Router } from "express";
import { sessionParser, userParser, asyncHandler } from "@/middlewares";
import {
  createTag,
  deleteTag,
  getSubTags,
  getTagById,
  getTags,
  updateTag,
} from "@/features/tags/controller";

const router = Router();

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /tags:
 *   get:
 *     tags: [Tags]
 *     summary: List tags
 *   post:
 *     tags: [Tags]
 *     summary: Create tag
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Tag'
 */
router.get("/", asyncHandler(getTags));
router.post("/", asyncHandler(createTag));
router
  .route("/:tagId")
  /**
   * @openapi
   * /tags/{tagId}:
   *   get:
   *     tags: [Tags]
   *     summary: Get tag by ID
   *     parameters:
   *       - in: path
   *         name: tagId
   *         required: true
   *         schema:
   *           type: string
   *   put:
   *     tags: [Tags]
   *     summary: Update tag
   *   delete:
   *     tags: [Tags]
   *     summary: Delete tag
   */
  .get(asyncHandler(getTagById))
  .put(asyncHandler(updateTag))
  .delete(asyncHandler(deleteTag));

/**
 * @openapi
 * /tags/{tagId}/sub-tags:
 *   get:
 *     tags: [Tags]
 *     summary: Get sub tags
 *     parameters:
 *       - in: path
 *         name: tagId
 *         required: true
 *         schema:
 *           type: string
 */
router.get("/:tagId/sub-tags", asyncHandler(getSubTags));

export default router;
