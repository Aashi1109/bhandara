/**
 * @openapi
 * components:
 *   securitySchemes:
 *     SessionCookieAuth:
 *       type: apiKey
 *       in: cookie
 *       name: bh_session
 *       description: Session cookie issued after login and required by protected endpoints.
 *   schemas:
 *     ApiError:
 *       type: object
 *       properties:
 *         message:
 *           type: string
 *         type:
 *           type: string
 *         status:
 *           type: integer
 *         additionalInfo:
 *           nullable: true
 *     ApiEnvelope:
 *       type: object
 *       properties:
 *         data:
 *           nullable: true
 *         error:
 *           oneOf:
 *             - $ref: '#/components/schemas/ApiError'
 *             - nullable: true
 *     PaginationMeta:
 *       type: object
 *       properties:
 *         limit:
 *           type: integer
 *         next:
 *           type: string
 *           nullable: true
 *         hasNext:
 *           type: boolean
 *         total:
 *           type: integer
 *           nullable: true
 *         sortBy:
 *           type: string
 *           enum: [createdAt, updatedAt]
 *         sortOrder:
 *           type: string
 *           enum: [asc, desc]
 *     PublicUser:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         username:
 *           type: string
 *           nullable: true
 *         profilePic:
 *           type: object
 *           nullable: true
 *         bio:
 *           type: string
 *           nullable: true
 *         isVerified:
 *           type: boolean
 *         isSocialLogin:
 *           type: boolean
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 *         deletedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *     User:
 *       allOf:
 *         - $ref: '#/components/schemas/PublicUser'
 *         - type: object
 *           properties:
 *             email:
 *               type: string
 *             gender:
 *               type: string
 *             address:
 *               type: object
 *               nullable: true
 *             meta:
 *               type: object
 *             mediaId:
 *               oneOf:
 *                 - type: string
 *                 - type: object
 *                 - type: 'null'
 *     Media:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         type:
 *           type: string
 *         url:
 *           type: string
 *         publicUrl:
 *           type: string
 *           nullable: true
 *         publicUrlExpiresAt:
 *           oneOf:
 *             - type: string
 *               format: date-time
 *             - type: number
 *             - type: 'null'
 *         caption:
 *           type: string
 *           nullable: true
 *         thumbnail:
 *           type: string
 *           nullable: true
 *         size:
 *           type: number
 *           nullable: true
 *         mimeType:
 *           type: string
 *           nullable: true
 *         duration:
 *           type: number
 *           nullable: true
 *         access:
 *           type: string
 *         metadata:
 *           type: object
 *         storage:
 *           type: object
 *         name:
 *           type: string
 *     Tag:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         value:
 *           type: string
 *         description:
 *           type: string
 *           nullable: true
 *         icon:
 *           type: string
 *           nullable: true
 *         color:
 *           type: string
 *           nullable: true
 *         parentId:
 *           type: string
 *           nullable: true
 *         createdBy:
 *           type: string
 *           nullable: true
 *         eventId:
 *           type: string
 *           nullable: true
 *     RatingHistogram:
 *       type: object
 *       properties:
 *         "1":
 *           type: integer
 *         "2":
 *           type: integer
 *         "3":
 *           type: integer
 *         "4":
 *           type: integer
 *         "5":
 *           type: integer
 *       required: ["1", "2", "3", "4", "5"]
 *     EngagementStats:
 *       type: object
 *       properties:
 *         viewCount:
 *           type: integer
 *         ratingCount:
 *           type: integer
 *         ratingAverage:
 *           type: number
 *         ratingHistogram:
 *           $ref: '#/components/schemas/RatingHistogram'
 *       required: [viewCount, ratingCount, ratingAverage, ratingHistogram]
 *     EventStats:
 *       type: object
 *       properties:
 *         reactionCount:
 *           type: integer
 *         threadCount:
 *           type: integer
 *         participantCount:
 *           type: integer
 *         verifierCount:
 *           type: integer
 *         mediaCount:
 *           type: integer
 *         tagCount:
 *           type: integer
 *         viewCount:
 *           type: integer
 *         ratingCount:
 *           type: integer
 *         ratingAverage:
 *           type: number
 *     ThreadStats:
 *       type: object
 *       properties:
 *         reactionCount:
 *           type: integer
 *         messageCount:
 *           type: integer
 *         viewCount:
 *           type: integer
 *         ratingCount:
 *           type: integer
 *         ratingAverage:
 *           type: number
 *     MessageStats:
 *       type: object
 *       properties:
 *         reactionCount:
 *           type: integer
 *         replyCount:
 *           type: integer
 *         viewCount:
 *           type: integer
 *         ratingCount:
 *           type: integer
 *         ratingAverage:
 *           type: number
 *     Event:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         description:
 *           type: string
 *         location:
 *           type: object
 *         participants:
 *           type: array
 *           items:
 *             type: object
 *         verifiers:
 *           type: array
 *           items:
 *             type: object
 *         type:
 *           type: string
 *         createdBy:
 *           type: string
 *         creator:
 *           $ref: '#/components/schemas/PublicUser'
 *         status:
 *           type: string
 *         capacity:
 *           type: integer
 *         tags:
 *           type: array
 *           items:
 *             oneOf:
 *               - $ref: '#/components/schemas/Tag'
 *               - type: string
 *         media:
 *           type: array
 *           items:
 *             oneOf:
 *               - $ref: '#/components/schemas/Media'
 *               - type: string
 *         stats:
 *           $ref: '#/components/schemas/EventStats'
 *         reactions:
 *           type: array
 *           items:
 *             type: object
 *         timings:
 *           type: object
 *           properties:
 *             start:
 *               type: string
 *               format: date-time
 *             end:
 *               type: string
 *               format: date-time
 *     Thread:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         visibility:
 *           type: string
 *         lockHistory:
 *           type: array
 *           items:
 *             type: object
 *         parentId:
 *           type: string
 *           nullable: true
 *         eventId:
 *           type: string
 *         stats:
 *           $ref: '#/components/schemas/ThreadStats'
 *         messages:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/Message'
 *         createdBy:
 *           type: string
 *         creator:
 *           $ref: '#/components/schemas/PublicUser'
 *     Message:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         userId:
 *           type: string
 *         parentId:
 *           type: string
 *           nullable: true
 *         content:
 *           type: object
 *         isEdited:
 *           type: boolean
 *         threadId:
 *           type: string
 *         stats:
 *           $ref: '#/components/schemas/MessageStats'
 *         user:
 *           $ref: '#/components/schemas/PublicUser'
 *         reactions:
 *           type: array
 *           items:
 *             type: object
 *     SavedEntitySummary:
 *       type: object
 *       properties:
 *         entityType:
 *           type: string
 *           enum: [event, thread, message]
 *         entityId:
 *           type: string
 *         saved:
 *           type: boolean
 *         saveCount:
 *           type: integer
 *         savedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *       required: [entityType, entityId, saved, saveCount, savedAt]
 *     SavedEntityListItem:
 *       allOf:
 *         - $ref: '#/components/schemas/SavedEntitySummary'
 *         - type: object
 *           properties:
 *             id:
 *               type: string
 *             userId:
 *               type: string
 *             createdAt:
 *               type: string
 *               format: date-time
 *             updatedAt:
 *               type: string
 *               format: date-time
 *             deletedAt:
 *               type: string
 *               format: date-time
 *               nullable: true
 *             entity:
 *               oneOf:
 *                 - $ref: '#/components/schemas/Event'
 *                 - $ref: '#/components/schemas/Thread'
 *                 - $ref: '#/components/schemas/Message'
 *                 - type: 'null'
 *     PaginatedSavedEntities:
 *       type: object
 *       properties:
 *         items:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/SavedEntityListItem'
 *         pagination:
 *           $ref: '#/components/schemas/PaginationMeta'
 *     PaginatedUsers:
 *       type: object
 *       properties:
 *         items:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/PublicUser'
 *         pagination:
 *           $ref: '#/components/schemas/PaginationMeta'
 *     PaginatedThreads:
 *       type: object
 *       properties:
 *         items:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/Thread'
 *         pagination:
 *           $ref: '#/components/schemas/PaginationMeta'
 *     PaginatedMessages:
 *       type: object
 *       properties:
 *         items:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/Message'
 *         pagination:
 *           $ref: '#/components/schemas/PaginationMeta'
 *     PaginatedEvents:
 *       type: object
 *       properties:
 *         items:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/Event'
 *         pagination:
 *           $ref: '#/components/schemas/PaginationMeta'
 *     EntityEngagement:
 *       type: object
 *       properties:
 *         viewCount:
 *           type: integer
 *         ratingCount:
 *           type: integer
 *         ratingAverage:
 *           type: number
 *         ratingHistogram:
 *           $ref: '#/components/schemas/RatingHistogram'
 *       required: [viewCount, ratingCount, ratingAverage, ratingHistogram]
 *     RateEntityRequest:
 *       type: object
 *       properties:
 *         value:
 *           type: integer
 *           minimum: 1
 *           maximum: 5
 *       required: [value]
 *     AuthResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         data:
 *           type: object
 *   parameters:
 *     EntityTypeParam:
 *       in: path
 *       name: entityType
 *       required: true
 *       schema:
 *         type: string
 *         enum: [users, events, threads, messages]
 *     EntityIdParam:
 *       in: path
 *       name: entityId
 *       required: true
 *       schema:
 *         type: string
 *     UserIdParam:
 *       in: path
 *       name: id
 *       required: true
 *       schema:
 *         type: string
 *   responses:
 *     RateLimited:
 *       description: Too many requests
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/ApiEnvelope'
 */
