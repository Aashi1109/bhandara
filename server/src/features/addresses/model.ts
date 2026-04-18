import { getDBConnection } from '@/connections/db';
import { EAddressEntityType } from '@/definitions/enums';
import { getUUIDv7 } from '@/helpers';
import { DataTypes, Model } from 'sequelize';
import { decryptRecordFields, encryptedTextAttribute } from '@/utils';

import { ADDRESS_TABLE_NAME } from './constants';

const sequelize = getDBConnection()!;

export interface AddressAttributes {
  id: string;
  entityType: EAddressEntityType;
  entityId: string;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

type AddressRecord = Omit<AddressAttributes, 'createdAt' | 'updatedAt'>;
type AddressCreationAttributes = AddressRecord;

export const ADDRESS_ENCRYPTED_FIELDS = ['address'] as const;
export const decryptAddressRow = <T extends Record<string, any>>(row: T) =>
  decryptRecordFields(row, ADDRESS_ENCRYPTED_FIELDS);
export const decryptAddressRows = <T extends Record<string, any>>(rows: T[]) => rows.map((row) => decryptAddressRow(row));

export class Address extends Model<AddressRecord, AddressCreationAttributes> {
  declare id: string;
  declare entityType: EAddressEntityType;
  declare entityId: string;
  declare address: string | null;
  declare latitude: number | null;
  declare longitude: number | null;
  declare metadata: Record<string, unknown>;
  declare createdAt: Date;
  declare updatedAt: Date;
}

Address.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    entityType: {
      type: DataTypes.ENUM(...Object.values(EAddressEntityType)),
      allowNull: false,
    },
    entityId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    address: encryptedTextAttribute('address', { allowNull: true }),
    latitude: {
      type: DataTypes.DOUBLE,
      allowNull: true,
    },
    longitude: {
      type: DataTypes.DOUBLE,
      allowNull: true,
    },
    metadata: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
  },
  {
    modelName: 'Address',
    tableName: ADDRESS_TABLE_NAME,
    sequelize,
    timestamps: true,
    indexes: [
      {
        name: 'addresses_entityType_entityId_key',
        unique: true,
        fields: ['entityType', 'entityId'],
      },
      {
        name: 'addresses_coords_gix',
        using: 'GIST',
        fields: [sequelize.literal(`ST_SetSRID(ST_MakePoint("longitude", "latitude"), 4326)`)],
      },
      { fields: ['entityType'] },
    ],
  },
);
