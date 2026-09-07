export const USER_ACHIEVEMENT_TABLE_NAME = 'UserAchievements';
export const ACHIEVEMENT_PROGRESS_TABLE_NAME = 'AchievementProgress';

export interface IAchievementDefinition {
  key: string;
  title: string;
  description: string;
  icon?: string;
  type: 'count' | 'streak';
  metric: string;
  threshold: number;
}

export const ACHIEVEMENT_DEFINITIONS: IAchievementDefinition[] = [
  {
    key: 'first_event',
    title: 'First Event',
    description: 'Create your first event.',
    icon: 'calendar',
    type: 'count',
    metric: 'event.created',
    threshold: 1,
  },
  {
    key: 'conversation_starter',
    title: 'Conversation Starter',
    description: 'Post 5 messages.',
    icon: 'message-circle',
    type: 'count',
    metric: 'message.created',
    threshold: 5,
  },
  {
    key: 'community_supporter',
    title: 'Community Supporter',
    description: 'React 10 times.',
    icon: 'heart',
    type: 'count',
    metric: 'reaction.created',
    threshold: 10,
  },
  {
    key: 'week_streak',
    title: 'Week Streak',
    description: 'Be active for 7 consecutive days.',
    icon: 'flame',
    type: 'streak',
    metric: 'streak.current',
    threshold: 7,
  },
];
