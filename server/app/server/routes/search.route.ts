import { Router } from 'express';
import { SearchController } from '@/src/features/search';
import { validateSuggestionsQuery } from '@/src/features/search/validation';

const router = Router();

/**
 * @openapi
 * /search:
 *   get:
 *     tags: [Search]
 *     summary: Search events
 *     description: Performs a relevance-ranked event search with optional filters for status, type, date preset, location radius, and tags.
 *     security: []
 *     parameters:
 *       - in: query
 *         name: query
 *         required: true
 *         schema:
 *           type: string
 *           minLength: 2
 *           maxLength: 100
 *       - in: query
 *         name: next
 *         schema:
 *           type: string
 *           nullable: true
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 20
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *         description: Comma-separated event statuses.
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *         description: Comma-separated event types.
 *       - in: query
 *         name: datePreset
 *         schema:
 *           type: string
 *           enum: [anytime, today, this_week, this_month]
 *       - in: query
 *         name: latitude
 *         schema:
 *           type: number
 *       - in: query
 *         name: longitude
 *         schema:
 *           type: number
 *       - in: query
 *         name: radiusKm
 *         schema:
 *           type: number
 *           minimum: 0
 *       - in: query
 *         name: tagIds
 *         schema:
 *           type: string
 *         description: Comma-separated tag IDs.
 *     responses:
 *       200:
 *         description: Search results
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedSearchResults'
 *                 error:
 *                   nullable: true
 *       400:
 *         description: Invalid search parameters
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/', SearchController.search);

/**
 * @openapi
 * /search/suggestions:
 *   get:
 *     tags: [Search]
 *     summary: Get search suggestions
 *     security: []
 *     parameters:
 *       - in: query
 *         name: query
 *         required: true
 *         schema:
 *           type: string
 *           minLength: 1
 *           maxLength: 50
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 20
 *           default: 5
 *     responses:
 *       200:
 *         description: Matching suggestion strings
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     type: string
 *                 error:
 *                   nullable: true
 *       400:
 *         description: Invalid suggestion query
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/suggestions', validateSuggestionsQuery, SearchController.getSuggestions);

/**
 * @openapi
 * /search/options:
 *   get:
 *     tags: [Search]
 *     summary: Get supported search filter options
 *     security: []
 *     responses:
 *       200:
 *         description: Search filter metadata
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/SearchOptions'
 *                 error:
 *                   nullable: true
 */
router.get('/options', SearchController.getSearchOptions);

export default router;
