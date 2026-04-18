import { Op, type Transaction } from 'sequelize';
import { EAddressEntityType, EAuthProvider } from '@/src/common/definitions/enums';
import { getUUIDv7 } from '@/src/common/helpers';
import { Address } from '@/src/features/addresses/model';
import { User } from '@/src/features/users/model';
import type { SeedCoordinatorUser, SeedOptions, SeededAuthUser } from './types';
import { buildAddress, buildSeedUserEmailLikePattern, bulkCreateInChunks, logSeedProgress } from './utils';

export async function findReusableSeedUsers(targetCount: number, options: SeedOptions) {
  if (!options.reuseExistingUsers || targetCount <= 0) {
    return [];
  }

  const reusableLimit = options.reuseMaxUsers ? Math.min(options.reuseMaxUsers, targetCount) : targetCount;
  if (reusableLimit <= 0) {
    return [];
  }

  const rows = await User.findAll({
    where: {
      email: {
        [Op.like]: buildSeedUserEmailLikePattern(options.emailPrefix),
      },
    },
    attributes: ['id', 'email', 'name'],
    order: [
      ['updatedAt', 'DESC'],
      ['id', 'ASC'],
    ],
    limit: reusableLimit,
    raw: true,
  });

  const users = rows.map((row) => ({
    id: row.id,
    email: row.email,
    name: row.name,
    source: 'existing' as const,
  }));

  logSeedProgress(`Resolved ${users.length} reusable seed users with prefix ${options.emailPrefix}`);
  return users;
}

export function buildCreatedUserRows(createdAuthUsers: SeededAuthUser[]) {
  return createdAuthUsers.map((authUser) => {
    const id = getUUIDv7();
    const address = buildAddress();
    const user = {
      id,
      email: authUser.email,
      name: authUser.name,
      source: 'created' as const,
    };

    return {
      user,
      row: {
        id,
        name: authUser.name,
        email: authUser.email,
        gender: authUser.gender,
        isVerified: true,
        profilePic: null,
        username: authUser.email.split('@')[0],
        password: null,
        meta: {
          auth: {
            provider: EAuthProvider.Email,
            supabaseUserId: authUser.authUserId,
            accessToken: authUser.accessToken,
            refreshToken: authUser.refreshToken,
            expiresAt: authUser.expiresAt,
            expiresIn: authUser.expiresIn,
          },
          hasOnboarded: true,
        },
      },
      addressRow: {
        id: getUUIDv7(),
        entityType: EAddressEntityType.User,
        entityId: id,
        address: address.address,
        latitude: address.latitude,
        longitude: address.longitude,
        metadata: {
          coordinates: address.coordinates,
        },
      },
    };
  });
}

export async function insertCreatedUsers(
  transaction: Transaction,
  createdAuthUsers: SeededAuthUser[],
  label: string,
): Promise<SeedCoordinatorUser[]> {
  if (createdAuthUsers.length === 0) {
    return [];
  }

  const builtRows = buildCreatedUserRows(createdAuthUsers);
  await bulkCreateInChunks(
    User,
    builtRows.map((entry) => entry.row),
    transaction,
    label,
  );
  await bulkCreateInChunks(
    Address,
    builtRows.map((entry) => entry.addressRow),
    transaction,
    `${label}:addresses`,
  );

  return builtRows.map((entry) => entry.user);
}
