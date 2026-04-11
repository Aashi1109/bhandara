import type { Transaction } from 'sequelize';
import { UserSettings, type UserSettingsAttributes } from './settings.model';
import { getUserSettingsCache, setUserSettingsCache } from './helpers';

type SettingsUpdateData = Partial<
  Pick<UserSettingsAttributes, 'notifications' | 'privacy' | 'onboarding' | 'interests'>
>;

const DEFAULTS = {
  notifications: { events: true, chat: true, replies: true, reminders: true },
  privacy: { shareLocation: false },
  onboarding: { hasOnboarded: false },
  interests: [] as string[],
};

class UserSettingsService {
  async getByUserId(userId: string): Promise<UserSettings | null> {
    const cached = await getUserSettingsCache<UserSettings>(userId);
    if (cached) return cached;

    const settings = await UserSettings.findOne({ where: { userId } });
    if (settings) await setUserSettingsCache(userId, settings);
    return settings;
  }

  async updateSettings(userId: string, data: SettingsUpdateData, transaction?: Transaction): Promise<UserSettings> {
    const existing = await UserSettings.findOne({ where: { userId }, transaction });

    let result: UserSettings;

    if (!existing) {
      result = await UserSettings.create(
        {
          userId,
          notifications: { ...DEFAULTS.notifications, ...data.notifications },
          privacy: { ...DEFAULTS.privacy, ...data.privacy },
          onboarding: { ...DEFAULTS.onboarding, ...data.onboarding },
          interests: data.interests ?? DEFAULTS.interests,
        } as UserSettingsAttributes,
        { transaction },
      );
    } else {
      const updates: Partial<UserSettingsAttributes> = {};

      if (data.notifications !== undefined) {
        updates.notifications = { ...existing.notifications, ...data.notifications };
      }
      if (data.privacy !== undefined) {
        updates.privacy = { ...existing.privacy, ...data.privacy };
      }
      if (data.onboarding !== undefined) {
        updates.onboarding = { ...existing.onboarding, ...data.onboarding };
      }
      if (data.interests !== undefined) {
        updates.interests = data.interests;
      }

      await existing.update(updates, { transaction });
      result = existing;
    }

    await setUserSettingsCache(userId, result);
    return result;
  }

  async ensureExists(userId: string): Promise<UserSettings> {
    const existing = await this.getByUserId(userId);
    if (existing) return existing;
    return this.updateSettings(userId, {});
  }
}

export default UserSettingsService;
