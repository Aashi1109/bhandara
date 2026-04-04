import dotenv from 'dotenv';
import { faker } from '@faker-js/faker';
import { QueryTypes, type CreationAttributes } from 'sequelize';

import { disconnect, getDBConnection } from '@/connections/db';
import { EAddressEntityType, EEventParticipantStatus, EEventStatus, EEventType } from '@/definitions/enums';
import { getUUIDv7 } from '@/helpers';
import { Address } from '@/features/addresses/model';
import { Event } from '@/features/events/model';
import { Tag } from '@/features/tags/model';
import { User } from '@/features/users/model';
import { clusterSeedConfigs, fallbackTagSeeds } from './clusterSeedConfig';

dotenv.config();

type SeedBand = 'near' | 'medium' | 'far';

type EventInsert = {
  id: string;
  name: string;
  description: string;
  participants: { user: string; status: EEventParticipantStatus }[];
  verifiers: { user: string; verifiedAt: string }[];
  type: EEventType;
  createdBy: string;
  status: EEventStatus;
  capacity: number;
  tags: string[];
  media: string[];
  timings: {
    start: string;
    end: string;
  };
};

type EventLocation = {
  address: string;
  venue: string;
  latitude: number;
  longitude: number;
  coordinates: {
    latitude: number;
    longitude: number;
  };
};

type SeedEventPayload = EventInsert & {
  location: EventLocation;
};

type CreatedEvent = {
  id: string;
  createdBy: string;
};

type AddressInsert = {
  id: string;
  entityType: EAddressEntityType;
  entityId: string;
  address: string;
  latitude: number;
  longitude: number;
  metadata: Record<string, unknown>;
};

const metersByBand: Record<SeedBand, { min: number; max: number }> = {
  near: { min: 20, max: 250 },
  medium: { min: 500, max: 2500 },
  far: { min: 7000, max: 40000 },
};

const eventNamePrefixes = [
  'Bhandara Meetup',
  'Community Feast',
  'Street Food Circle',
  'Open Plate Gathering',
  'Local Tasting Stop',
  'Dinner Drop',
  'Weekend Food Run',
  'Shared Table Session',
];

const eventNameSuffixes = ['Pop-up', 'Edition', 'Night', 'Hangout', 'Special', 'Circle', 'Club', 'Trail'];

function toRadians(value: number) {
  return (value * Math.PI) / 180;
}

function toDegrees(value: number) {
  return (value * 180) / Math.PI;
}

function offsetCoordinates(latitude: number, longitude: number, distanceMeters: number, bearingDegrees: number) {
  const earthRadius = 6371000;
  const angularDistance = distanceMeters / earthRadius;
  const bearing = toRadians(bearingDegrees);
  const lat1 = toRadians(latitude);
  const lon1 = toRadians(longitude);

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(angularDistance) + Math.cos(lat1) * Math.sin(angularDistance) * Math.cos(bearing),
  );

  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(bearing) * Math.sin(angularDistance) * Math.cos(lat1),
      Math.cos(angularDistance) - Math.sin(lat1) * Math.sin(lat2),
    );

  return {
    latitude: Number(toDegrees(lat2).toFixed(6)),
    longitude: Number(toDegrees(lon2).toFixed(6)),
  };
}

function buildParticipants(allUserIds: string[], ownerId: string) {
  const participantCount = faker.number.int({ min: 0, max: Math.min(6, allUserIds.length) });
  const others = faker.helpers.arrayElements(
    allUserIds.filter((userId) => userId !== ownerId),
    participantCount,
  );

  return others.map((userId) => ({
    user: userId,
    status: faker.helpers.weightedArrayElement([
      { value: EEventParticipantStatus.Confirmed, weight: 6 },
      { value: EEventParticipantStatus.Pending, weight: 3 },
      { value: EEventParticipantStatus.Declined, weight: 1 },
    ]),
  }));
}

function buildVerifiers(participants: { user: string; status: EEventParticipantStatus }[]) {
  const confirmedUsers = participants
    .filter((participant) => participant.status === EEventParticipantStatus.Confirmed)
    .map((participant) => participant.user);

  return faker.helpers
    .arrayElements(confirmedUsers, faker.number.int({ min: 0, max: Math.min(2, confirmedUsers.length) }))
    .map((userId) => ({
      user: userId,
      verifiedAt: faker.date.recent({ days: 5 }).toISOString(),
    }));
}

function buildTimings() {
  const start = faker.date.soon({ days: 45 });
  const end = new Date(start.getTime() + faker.number.int({ min: 90, max: 360 }) * 60 * 1000);

  return {
    start: start.toISOString(),
    end: end.toISOString(),
  };
}

function buildEventPayload(args: {
  ownerId: string;
  allUserIds: string[];
  tagIds: string[];
  clusterName: string;
  latitude: number;
  longitude: number;
  band: SeedBand;
}) {
  const participants = buildParticipants(args.allUserIds, args.ownerId);
  const verifiers = buildVerifiers(participants);
  const timings = buildTimings();
  const tags = faker.helpers.arrayElements(
    args.tagIds,
    faker.number.int({ min: 1, max: Math.min(3, args.tagIds.length) }),
  );
  const venue = `${faker.company.name()} ${faker.helpers.arrayElement(['Hall', 'Ground', 'Courtyard', 'Center', 'Kitchen'])}`;
  const location = {
    address: faker.location.streetAddress({ useFullAddress: true }),
    venue,
    latitude: args.latitude,
    longitude: args.longitude,
    coordinates: {
      latitude: args.latitude,
      longitude: args.longitude,
    },
  };

  const eventId = getUUIDv7();

  return {
    id: eventId,
    name: `${faker.helpers.arrayElement(eventNamePrefixes)} ${args.clusterName} ${faker.helpers.arrayElement(eventNameSuffixes)}`,
    description: `${faker.lorem.sentences({ min: 2, max: 4 })} Seed band: ${args.band}.`,
    location,
    participants,
    verifiers,
    type: faker.helpers.arrayElement([EEventType.Organized, EEventType.Custom]),
    createdBy: args.ownerId,
    status: faker.helpers.weightedArrayElement([
      { value: EEventStatus.Upcoming, weight: 8 },
      { value: EEventStatus.Ongoing, weight: 1 },
      { value: EEventStatus.Draft, weight: 1 },
    ]),
    capacity: faker.number.int({ min: 50, max: 250 }),
    tags,
    media: [],
    timings,
  } satisfies SeedEventPayload;
}

async function ensureTags() {
  let tags = await Tag.findAll({ attributes: ['id'], raw: true });

  if (tags.length === 0) {
    await Tag.bulkCreate(fallbackTagSeeds as any);
    tags = await Tag.findAll({ attributes: ['id'], raw: true });
  }

  return tags.map((tag) => tag.id);
}

async function main() {
  const sequelize = getDBConnection()!;
  await sequelize.authenticate();

  const users = await User.findAll({ attributes: ['id'], raw: true });
  if (users.length === 0) {
    throw new Error('No users found. Create users before running the cluster seed.');
  }

  const userIds = users.map((user) => user.id);
  const tagIds = await ensureTags();
  if (tagIds.length === 0) {
    throw new Error('No tags available for event creation.');
  }

  const payloads: SeedEventPayload[] = [];
  const addressRows: AddressInsert[] = [];
  for (const cluster of clusterSeedConfigs) {
    const bandCounts: Record<SeedBand, number> = {
      near: cluster.nearCount,
      medium: cluster.mediumCount,
      far: cluster.farCount,
    };

    for (const band of Object.keys(bandCounts) as SeedBand[]) {
      for (let index = 0; index < bandCounts[band]; index += 1) {
        const distance = faker.number.int(metersByBand[band]);
        const bearing = faker.number.int({ min: 0, max: 359 });
        const point = offsetCoordinates(cluster.latitude, cluster.longitude, distance, bearing);
        const ownerId = userIds[(payloads.length + index) % userIds.length];

        const payload = buildEventPayload({
          ownerId,
          allUserIds: userIds,
          tagIds,
          clusterName: cluster.name,
          latitude: point.latitude,
          longitude: point.longitude,
          band,
        });

        payloads.push(payload);
        addressRows.push({
          id: getUUIDv7(),
          entityType: EAddressEntityType.Event,
          entityId: payload.id,
          address: payload.location.address,
          latitude: payload.location.latitude,
          longitude: payload.location.longitude,
          metadata: {
            venue: payload.location.venue,
            coordinates: payload.location.coordinates,
          },
        });
      }
    }
  }

  const transaction = await sequelize.transaction();

  try {
    const created = (await Event.bulkCreate(
      payloads.map(({ location: _location, ...event }) => event) as unknown as CreationAttributes<Event>[],
      {
        transaction,
        returning: ['id', 'createdBy'],
      },
    )) as unknown as CreatedEvent[];

    await Address.bulkCreate(addressRows as unknown as CreationAttributes<Address>[], {
      transaction,
    });

    await transaction.commit();

    const summary = (await sequelize.query(
      `
        SELECT "createdBy", COUNT(*)::text AS "eventCount"
        FROM "Events"
        WHERE "createdAt" >= NOW() - INTERVAL '10 minutes'
        GROUP BY "createdBy"
        ORDER BY COUNT(*) DESC, "createdBy" ASC
        LIMIT 10
      `,
      { type: QueryTypes.SELECT },
    )) as { createdBy: string; eventCount: string }[];

    console.log(`Created ${created.length} clustered events across ${clusterSeedConfigs.length} city groups.`);
    console.log('Top creators from this recent seed window:');
    summary.forEach((row) => {
      console.log(`- ${row.createdBy}: ${row.eventCount} events`);
    });
  } catch (error) {
    await transaction.rollback();
    throw error;
  } finally {
    await disconnect();
  }
}

main().catch((error) => {
  console.error('Cluster seed failed:', error);
  disconnect().finally(() => process.exit(1));
});
