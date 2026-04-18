import { Router } from 'express';
import { sessionParser, userParser, asyncHandler } from '../middlewares';
import { createTag, deleteTag, getSubTags, getTagById, getTags, updateTag } from '@/src/features/tags/controller';
import { validateTagCreate, validateTagUpdate } from '@/src/features/tags/validation';

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
 *     responses:
 *       200:
 *         description: Tag list or created tag
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/', asyncHandler(getTags));
router.post('/', validateTagCreate, asyncHandler(createTag));
router
  .route('/:tagId')
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
   *     responses:
   *       200:
   *         description: Tag detail
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/ApiEnvelope'
   *   put:
   *     tags: [Tags]
   *     summary: Update tag
   *     parameters:
   *       - in: path
   *         name: tagId
   *         required: true
   *         schema:
   *           type: string
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/Tag'
   *     responses:
   *       200:
   *         description: Updated tag
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/ApiEnvelope'
   *   delete:
   *     tags: [Tags]
   *     summary: Delete tag
   *     parameters:
   *       - in: path
   *         name: tagId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Deleted tag
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/ApiEnvelope'
   */
  .get(asyncHandler(getTagById))
  .put(validateTagUpdate, asyncHandler(updateTag))
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
 *     responses:
 *       200:
 *         description: Child tags
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/:tagId/sub-tags', asyncHandler(getSubTags));

export default router;
