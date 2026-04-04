import { EAddressEntityType } from '@/definitions/enums';
import type { ILocation } from '@/definitions/types';
import { getUUIDv7 } from '@/helpers';
import { Op, Sequelize, type Transaction } from 'sequelize';

import { Address, type AddressAttributes } from './model';

type LocationLike = Record<string, any> | null | undefined;

class AddressService {
  private get escape() {
    return Address.sequelize!.escape.bind(Address.sequelize);
  }

  private extractCoordinates(location: LocationLike) {
    if (!location || typeof location !== 'object') {
      return { latitude: null, longitude: null };
    }

    const directLatitude = Number(location.latitude);
    const directLongitude = Number(location.longitude);
    const nestedLatitude = Number(location.coordinates?.latitude);
    const nestedLongitude = Number(location.coordinates?.longitude);

    const latitude = Number.isFinite(directLatitude)
      ? directLatitude
      : Number.isFinite(nestedLatitude)
          ? nestedLatitude
          : null;
    const longitude = Number.isFinite(directLongitude)
      ? directLongitude
      : Number.isFinite(nestedLongitude)
          ? nestedLongitude
          : null;

    return { latitude, longitude };
  }

  private toAddressRow(entityType: EAddressEntityType, entityId: string, location: LocationLike) {
    if (!location || typeof location !== 'object') {
      return null;
    }

    const { latitude, longitude } = this.extractCoordinates(location);
    const metadata = { ...location } as Record<string, unknown>;
    delete metadata.address;
    delete metadata.latitude;
    delete metadata.longitude;
    delete metadata.coordinates;

    return {
      id: getUUIDv7(),
      entityType,
      entityId,
      address: typeof location.address === 'string' ? location.address : null,
      latitude,
      longitude,
      metadata,
    };
  }

  toLocation(address: Pick<AddressAttributes, 'address' | 'latitude' | 'longitude' | 'metadata'> | null): ILocation | null {
    if (!address) {
      return null;
    }

    const location: Record<string, unknown> = {
      ...(address.metadata || {}),
    };

    if (typeof address.address === 'string') {
      location.address = address.address;
    }

    if (Number.isFinite(address.latitude) && Number.isFinite(address.longitude)) {
      location.latitude = address.latitude;
      location.longitude = address.longitude;
      location.coordinates = {
        latitude: address.latitude,
        longitude: address.longitude,
      };
    }

    return location as ILocation;
  }

  async getByEntity(entityType: EAddressEntityType, entityId: string) {
    return Address.findOne({
      where: { entityType, entityId },
      raw: true,
    }) as Promise<AddressAttributes | null>;
  }

  async getByEntities(entityType: EAddressEntityType, entityIds: string[]) {
    if (entityIds.length === 0) {
      return {};
    }

    const rows = (await Address.findAll({
      where: {
        entityType,
        entityId: { [Op.in]: entityIds },
      },
      raw: true,
    })) as AddressAttributes[];

    return rows.reduce(
      (acc, row) => {
        acc[row.entityId] = row;
        return acc;
      },
      {} as Record<string, AddressAttributes>,
    );
  }

  async replaceAddress(
    entityType: EAddressEntityType,
    entityId: string,
    location: LocationLike,
    transaction?: Transaction,
  ) {
    const row = this.toAddressRow(entityType, entityId, location);
    await Address.destroy({ where: { entityType, entityId }, transaction });

    if (!row) {
      return null;
    }

    const created = await Address.create(row, { transaction });
    return created.toJSON() as AddressAttributes;
  }

  buildEntityDistanceClause({
    entityType,
    entityIdColumn,
    latitude,
    longitude,
    radiusKm,
  }: {
    entityType: EAddressEntityType;
    entityIdColumn: string;
    latitude: number;
    longitude: number;
    radiusKm: number;
  }) {
    const escapedEntityType = this.escape(entityType);
    const escapedLatitude = this.escape(latitude);
    const escapedLongitude = this.escape(longitude);
    const escapedRadiusMeters = this.escape(radiusKm * 1000);

    return Sequelize.literal(`
      EXISTS (
        SELECT 1
        FROM "Addresses" AS "EntityAddress"
        WHERE "EntityAddress"."entityType" = ${escapedEntityType}
          AND "EntityAddress"."entityId" = ${entityIdColumn}
          AND "EntityAddress"."latitude" IS NOT NULL
          AND "EntityAddress"."longitude" IS NOT NULL
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint("EntityAddress"."longitude", "EntityAddress"."latitude"), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${escapedLongitude}, ${escapedLatitude}), 4326)::geography,
            ${escapedRadiusMeters}
          )
      )
    `);
  }
}

export default AddressService;
