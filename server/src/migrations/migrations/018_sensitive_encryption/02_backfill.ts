import { type Sequelize, type Transaction, QueryTypes } from 'sequelize';
import { encryptRecordFields, hashForLookup } from '@/common/utils';

interface MigrationContext {
  sequelize: Sequelize;
  transaction: Transaction;
}

interface UserRow {
  id: string;
  email: string;
  __sid: string | null;
  meta: Record<string, any> | null;
}

interface AddressRow {
  id: string;
  address: string | null;
}

const USER_ENCRYPTED_FIELDS = ['email', '__sid'] as const;
const ADDRESS_ENCRYPTED_FIELDS = ['address'] as const;

const removeSupabaseIdFromMeta = (meta: Record<string, any> | null) => {
  if (!meta || typeof meta !== 'object') {
    return meta;
  }

  const nextMeta = JSON.parse(JSON.stringify(meta)) as Record<string, any>;
  const auth = nextMeta.auth;

  if (!auth || typeof auth !== 'object' || !('supabaseId' in auth)) {
    return meta;
  }

  delete auth.supabaseId;
  if (Object.keys(auth).length === 0) {
    delete nextMeta.auth;
  }

  return nextMeta;
};

const updateRow = async (
  sequelize: Sequelize,
  transaction: Transaction,
  tableName: string,
  id: string,
  values: Record<string, unknown>,
) => {
  const keys = Object.keys(values);
  if (keys.length === 0) {
    return;
  }

  const assignments = keys.map((key) => `"${key}" = :${key}`);
  await sequelize.query(`UPDATE "${tableName}" SET ${assignments.join(', ')}, "updatedAt" = NOW() WHERE "id" = :id`, {
    replacements: { id, ...values },
    transaction,
  });
};

export default async function runSensitiveEncryptionBackfill({ sequelize, transaction }: MigrationContext) {
  const users = await sequelize.query<UserRow>('SELECT "id", "email", "__sid", "meta" FROM "Users"', {
    transaction,
    type: QueryTypes.SELECT,
  });

  for (const user of users) {
    const supabaseIdFromMeta =
      user.meta && typeof user.meta === 'object' ? (user.meta.auth?.supabaseId as string | null | undefined) : null;
    const sid = user.__sid ?? supabaseIdFromMeta ?? null;
    const encryptedUser = encryptRecordFields(
      {
        __sid: sid,
        email: user.email,
      },
      USER_ENCRYPTED_FIELDS,
    );

    await updateRow(sequelize, transaction, 'Users', user.id, {
      __sid: encryptedUser.__sid,
      email: encryptedUser.email,
      emailLookupHash: hashForLookup(user.email),
      meta: JSON.stringify(removeSupabaseIdFromMeta(user.meta)),
    });
  }

  const addresses = await sequelize.query<AddressRow>(
    'SELECT "id", "address" FROM "Addresses" WHERE "address" IS NOT NULL',
    {
      transaction,
      type: QueryTypes.SELECT,
    },
  );

  for (const address of addresses) {
    const encryptedAddress = encryptRecordFields(address, ADDRESS_ENCRYPTED_FIELDS);

    await updateRow(sequelize, transaction, 'Addresses', address.id, {
      address: encryptedAddress.address,
    });
  }
}
