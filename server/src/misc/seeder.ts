// @ts-nocheck
import { createClient } from "@supabase/supabase-js";
import { faker } from "@faker-js/faker";
import dotenv from "dotenv";
import fs from "fs/promises";
import path, { dirname } from "path";

import {
  EAccessLevel,
  EEventStatus,
  EEventType,
  EThreadType,
} from "@/definitions/enums";
import { getUUIDv7 } from "@/helpers";
import { fileURLToPath } from "url";
import { MediaService } from "@/features";
import { MEDIA_FILE_BUCKET_NAME } from "@/features/media/constants";
import { TAG_TABLE_NAME } from "@/features/tags/constants";

dotenv.config();

const mediaService = new MediaService();

const foodEventTags = [
  {
    name: "Food Festival",
    value: "food-festival",
    description:
      "Large-scale events celebrating food, often with multiple vendors.",
    icon: "🎪",
    color: "#FF5733",
  },
  {
    name: "Cooking Class",
    value: "cooking-class",
    description: "Events where participants learn how to cook specific dishes.",
    icon: "👩‍🍳",
    color: "#FFA500",
  },
  {
    name: "Tasting Event",
    value: "tasting-event",
    description: "Events focused on sampling various foods or beverages.",
    icon: "🍷",
    color: "#800080",
  },
  {
    name: "Wine Pairing",
    value: "wine-pairing",
    description: "Events centered around pairing wines with specific dishes.",
    icon: "🍇",
    color: "#B10DC9",
  },
  {
    name: "Street Food",
    value: "street-food",
    description: "Events featuring popular street foods from around the world.",
    icon: "🌮",
    color: "#E67E22",
  },
  {
    name: "Vegan Event",
    value: "vegan-event",
    description: "Events dedicated to vegan food and culture.",
    icon: "🥦",
    color: "#27AE60",
  },
  {
    name: "Food Truck Rally",
    value: "food-truck-rally",
    description:
      "Gatherings of multiple food trucks offering various cuisines.",
    icon: "🚚",
    color: "#2980B9",
  },
  {
    name: "Dessert Tasting",
    value: "dessert-tasting",
    description:
      "Events focusing on cakes, pastries, and other sweet delights.",
    icon: "🍰",
    color: "#FFC0CB",
  },
  {
    name: "Barbecue",
    value: "barbecue",
    description: "Events centered around grilled and smoked meats.",
    icon: "🍖",
    color: "#8B0000",
  },
  {
    name: "Cultural Cuisine",
    value: "cultural-cuisine",
    description: "Celebrating traditional dishes from different cultures.",
    icon: "🌍",
    color: "#34495E",
  },
  {
    name: "Farm to Table",
    value: "farm-to-table",
    description: "Events promoting local and sustainable food sourcing.",
    icon: "🌱",
    color: "#2ECC71",
  },
  {
    name: "Chef's Table",
    value: "chefs-table",
    description: "Exclusive dining experiences with curated menus.",
    icon: "🍽️",
    color: "#D4AC0D",
  },
  {
    name: "Beer Tasting",
    value: "beer-tasting",
    description: "Sampling craft beers and learning about brewing.",
    icon: "🍺",
    color: "#F1C40F",
  },
  {
    name: "Cocktail Night",
    value: "cocktail-night",
    description: "Evenings dedicated to cocktails and mixology.",
    icon: "🍸",
    color: "#9B59B6",
  },
  {
    name: "Brunch Social",
    value: "brunch-social",
    description: "Casual brunches for socializing and networking.",
    icon: "🥞",
    color: "#F39C12",
  },
];

// Init Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const trueOrFalse = () => faker.helpers.arrayElement([true, false]);

async function main() {
  await supabase.rpc("begin");
  const { data: insertedTags, error: tagErr } = await supabase
    .from(TAG_TABLE_NAME)
    .insert(foodEventTags)
    .select();

  if (tagErr) throw tagErr;

  console.log(
    `Inserted predefined ${insertedTags?.length} tags to ${TAG_TABLE_NAME}`
  );

  const { data: users, error: userErr } = await supabase
    .from("Users")
    .select("id");
  if (userErr || !users || users.length === 0)
    throw new Error("No users found in Users table");

  const eventsPayload = [...Array(5)].map(() => ({
    name: faker.company.name(),
    description: faker.lorem.paragraph(),
    location: {
      coordinates: {
        latitude: faker.location.latitude(),
        longitude: faker.location.longitude(),
      },
      address: faker.location.streetAddress(),
      venue: faker.location.city(),
    },
    participants: [],
    verifiers: [],
    type: faker.helpers.arrayElement(Object.values(EEventType)),
    createdBy: faker.helpers.arrayElement(users).id,
    status: faker.helpers.arrayElement(Object.values(EEventStatus)),
    capacity: faker.number.int({ min: 10, max: 200 }),
  }));

  const { data: events, error: eventErr } = await supabase
    .from("Events")
    .insert(eventsPayload)
    .select();
  if (eventErr) throw eventErr;

  const uploadedMedias = await seedMedia({
    folderData: events.map((event) => ({
      id: event.id,
      userId: event.createdBy,
    })),
    subPath: "assets/events",
  });

  const [
    { data: eventMediaJunctionInsertResponse, error: eventMediaErr },
    { data: eventTagsJunction, error: eventTagsErr },
  ] = await Promise.all([
    supabase
      .from("EventMedia")
      .insert(
        uploadedMedias.map((media) => ({
          mediaId: media.mediaId,
          eventId: media.parentId,
        }))
      )
      .select(),
    supabase
      .from("EventTags")
      .insert(
        events.flatMap((event) => {
          // Get random number of tags (1-10) for this event
          const numTags = faker.number.int({ min: 1, max: 10 });
          // Get random unique tags for this event
          const eventTags = faker.helpers.arrayElements(insertedTags, numTags);
          // Map to junction table format
          return eventTags.map((tag) => ({
            eventId: event.id,
            tagId: tag.id,
          }));
        })
      )
      .select(),
  ]);

  if (eventMediaErr) throw eventMediaErr;
  if (eventTagsErr) throw eventTagsErr;

  console.log(
    `Added ${eventMediaJunctionInsertResponse.length} rows to EventMedia`,
    `Added ${eventTagsJunction.length} rows to EventTags`
  );

  // Create Threads for each event
  const threadsPayload = events.map((event, index) => ({
    type: faker.helpers.arrayElement(Object.values(EThreadType)),
    status: faker.helpers.arrayElement(Object.values(EAccessLevel)),
    visibility: faker.helpers.arrayElement(Object.values(EAccessLevel)),
    eventId: event.id,
    lockHistory: {},
    createdAt: new Date(Date.now() + index),
    updatedAt: new Date(Date.now() + index),
  }));

  const { data: threads, error: threadErr } = await supabase
    .from("Threads")
    .insert(threadsPayload)
    .select("id, eventId");
  if (threadErr) throw threadErr;

  // Create Messages with parentId nesting
  for (const thread of threads) {
    const rootMessages: { id: string }[] = [];

    const messagesMedia = await seedMedia({
      folderData: Array({ length: 100 }).map(() => ({
        id: null,
        userId: faker.helpers.arrayElement(users).id,
        parentPath: thread.eventId,
      })),
      subPath: "assets/messages",
    });

    // Insert root-level messages
    const rootPayload = [...Array(faker.number.int({ min: 3, max: 20 }))].map(
      (_, index) => {
        const content = { text: faker.lorem.sentence() };

        const haveDynamicContent = trueOrFalse();
        const insertImages = trueOrFalse();
        const insertVideo = trueOrFalse();

        if (haveDynamicContent) {
          if (insertImages) {
            content["media"] = [
              ...(content?.media || []),
              ...faker.helpers.arrayElements(
                messagesMedia
                  .filter((m) => m.mediaType === "image")
                  .map((m) => m.mediaId),
                faker.number.int({ min: 1, max: 3 })
              ),
            ];
          }

          if (insertVideo) {
            content["media"] = [
              ...(content?.media || []),
              ...faker.helpers.arrayElements(
                messagesMedia
                  .filter((m) => m.mediaType === "video")
                  .map((m) => m.mediaId),
                faker.number.int({ min: 1, max: 3 })
              ),
            ];
          }
        }

        return {
          id: getUUIDv7(),
          userId: faker.helpers.arrayElement(users).id,
          parentId: null,
          content,
          createdAt: new Date(Date.now() + index),
          updatedAt: new Date(Date.now() + index),
          threadId: thread.id,
        };
      }
    );

    rootMessages.push(...rootPayload.map((m) => ({ id: m.id })));

    const { error: rootErr } = await supabase
      .from("Messages")
      .insert(rootPayload);
    if (rootErr) throw rootErr;

    // Insert child replies to random root messages
    const repliesPayload = [
      ...Array(faker.number.int({ min: 3, max: 1000 })),
    ].map((_, index) => {
      const content = { text: faker.lorem.sentence() };

      const haveDynamicContent = trueOrFalse();
      const insertImages = trueOrFalse();
      const insertVideo = trueOrFalse();

      if (haveDynamicContent) {
        if (insertImages) {
          content["media"] = [
            ...(content?.media || []),
            ...faker.helpers.arrayElements(
              messagesMedia
                .filter((m) => m.mediaType === "image")
                .map((m) => m.mediaId),
              faker.number.int({ min: 1, max: 3 })
            ),
          ];
        }

        if (insertVideo) {
          content["media"] = [
            ...(content?.media || []),
            ...faker.helpers.arrayElements(
              messagesMedia
                .filter((m) => m.mediaType === "video")
                .map((m) => m.mediaId),
              faker.number.int({ min: 1, max: 3 })
            ),
          ];
        }
      }

      return {
        id: getUUIDv7(),
        userId: faker.helpers.arrayElement(users).id,
        parentId: faker.helpers.arrayElement(rootMessages).id,
        content,
        threadId: thread.id,
        isEdited: false,
        createdAt: new Date(Date.now() + index),
        updatedAt: new Date(Date.now() + index),
      };
    });

    const { error: replyErr } = await supabase
      .from("Messages")
      .insert(repliesPayload);
    if (replyErr) throw replyErr;
  }

  console.log("✅ Seed complete with nested parentId messages.");
  await supabase.rpc("commit");
}

async function seedMedia({
  folderData,
  subPath,
}: {
  folderData: { id: string; userId: string; parentPath?: string }[];
  subPath: string;
}) {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const assetsPath = path.join(__dirname, subPath);

  const entries = await fs.readdir(assetsPath, { withFileTypes: true });

  // Filter only files
  const files = entries
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name);

  const uploadMediaData = [];

  const uploadConfig = folderData.map((f) => ({
    ...f,
    numUploads: faker.number.int({ min: 0, max: files.length }),
  }));

  const uploadPromises = uploadConfig.flatMap(async (_data) => {
    const uploads = [];

    const filesToUpload = faker.helpers.arrayElements(files, _data.numUploads);
    const _promises = filesToUpload.map(async (f, i) => {
      // For each upload, randomly select a file from the available files
      const filePath = path.join(assetsPath, f);
      const fileBuffer = await fs.readFile(filePath);

      const mimeType = getMimeType(f);
      if (!mimeType) {
        console.error(`❌ Failed to get mime type for ${f}`);
        return [];
      }

      try {
        // Step 1: Get signed URL
        const pathJoinParams = [_data.parentPath, _data.id, f].filter(Boolean);

        const { data: signedUrl } = await mediaService.getSignedUrlForUpload({
          bucket: MEDIA_FILE_BUCKET_NAME,
          path: path.join(...pathJoinParams),
          mimeType,
          options: {
            size: fileBuffer.length,
            name: `${i}_${path.basename(f)}`,
            type: mimeType.split("/")[0],
            uploader: _data.userId,
          },
        });

        await fetch(signedUrl.signedUrl, {
          method: "PUT",
          headers: { "Content-Type": mimeType },
          body: fileBuffer,
        });

        console.log(`✅ Uploaded ${i}_${f} to ${signedUrl.path}`);
        uploads.push({
          mediaId: signedUrl.row.id,
          parentId: _data.id,
          mediaType: signedUrl.row.type,
        });
      } catch (error) {
        console.error(`Error uploading file`, error);
      }
    });
    await Promise.all(_promises);
    return uploads;
  });

  const results = await Promise.all(uploadPromises);
  uploadMediaData.push(...results.flatMap((i) => i));

  return uploadMediaData;
}

function getMimeType(fileName) {
  const ext = path.extname(fileName).toLowerCase();
  const mimeMap = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
  };
  return mimeMap[ext];
}

main()
  .then(() => {
    console.log("✅ Seeding complete");
    process.exit(0);
  })
  .catch(async (err) => {
    await supabase.rpc("rollback");
    console.error("❌ Seeding failed:", err.message);
    process.exit(1);
  });
