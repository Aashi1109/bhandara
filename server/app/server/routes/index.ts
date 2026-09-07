import express from 'express';
import authRoutes from './auth.route';
import engagementRoutes from './engagement.route';
import eventsRoutes from './events.route';
import mediaRoutes from './media.route';
import savesRoutes from './saves.route';
import searchRoutes from './search.route';
import tagsRoutes from './tags.route';
import threadsRoutes from './threads.route';
import usersRoutes from './users.route';
import webhooksRoutes from './webhooks.route';

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/engagement', engagementRoutes);
router.use('/events', eventsRoutes);
router.use('/media', mediaRoutes);
router.use('/saves', savesRoutes);
router.use('/search', searchRoutes);
router.use('/tags', tagsRoutes);
router.use('/threads', threadsRoutes);
router.use('/users', usersRoutes);
router.use('/webhooks', webhooksRoutes);

export default router;
