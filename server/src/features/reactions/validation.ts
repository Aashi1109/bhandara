import { ajv, validateSchema } from "@/helpers";
import { REACTION_TABLE_NAME, EAllowedReactionTables } from "./constants";

ajv.addFormat("emoji", {
  type: "string",
  validate: (value: string) => {
    const trimmed = value.trim();
    if (!trimmed) return false;
    if (/[A-Za-z]/.test(trimmed)) return false;
    return /[\p{Extended_Pictographic}\p{Emoji_Presentation}\p{Regional_Indicator}\uFE0F\u200D]/u.test(
      trimmed
    );
  },
});

const allowedContentPaths = Object.values(EAllowedReactionTables);
const basePattern = `^(${allowedContentPaths.join("|")})\\/[0-9a-fA-F-]{36}$`;

const reactionSchema = {
  type: "object",
  properties: {
    contentId: {
      type: "string",
      pattern: basePattern,
      errorMessage: `contentId must be of the form '<table>/<uuid>' where table is one of ${allowedContentPaths.join(
        ", "
      )}`,
    },
    emoji: {
      type: "string",
      format: "emoji",
      minLength: 1,
      errorMessage: "emoji must be a valid emoji",
    },
    userId: {
      type: "string",
      format: "uuid",
      errorMessage: "userId must be a valid UUID",
    },
  },
  required: ["contentId", "emoji", "userId"],
  additionalProperties: false,
  errorMessage: {
    type: "Reaction data must be an object",
    required: {
      contentId: "contentId is required",
      emoji: "emoji is required",
      userId: "userId is required",
    },
  },
};

const updateSchema = {
  type: "object",
  properties: {
    contentId: {
      type: "string",
      pattern: basePattern,
      errorMessage: `contentId must be of the form '<table>/<uuid>' where table is one of ${allowedContentPaths.join(
        ", "
      )}`,
    },
    emoji: {
      type: "string",
      format: "emoji",
      minLength: 1,
      errorMessage: "emoji must be a valid emoji",
    },
    userId: {
      type: "string",
      format: "uuid",
      errorMessage: "userId must be a valid UUID",
    },
  },
  additionalProperties: false,
  errorMessage: {
    type: "Reaction data must be an object",
  },
};

export const validateReactionCreate = validateSchema(
  `${REACTION_TABLE_NAME}_CREATE`,
  reactionSchema
);

export const validateReactionUpdate = validateSchema(
  `${REACTION_TABLE_NAME}_UPDATE`,
  updateSchema
);
