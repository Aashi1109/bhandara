# Important note

## to enable superuser based extension in boltic tables

```js
"use strict";

const dotenv = require("dotenv");
const { logger } = require("fit/tracing");
const { appConfig } = require("../config");
const { DatabaseStatusEnum } = require("../app/models/enum");
const {
  constructVaultPath,
  constructVaultPathForDedicatedInstance,
  getConnectionStringFromVault,
  getDataFromVault,
} = require("../app/utils/vault");
const {
  createSequelizeInstance,
} = require("../app/utils/db_utils");
const {
  updateDatabaseNameInConnectionString,
} = require("../app/utils/common");

dotenv.config();

const DEFAULT_EXTENSIONS = ["postgis"];
const VALID_EXTENSION_NAME = /^[a-zA-Z0-9_-]+$/;

function parseArgs(argv) {
  const args = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      continue;
    }

    const key = token.slice(2);
    const value = argv[index + 1];

    if (!value || value.startsWith("--")) {
      args[key] = true;
      continue;
    }

    args[key] = value;
    index += 1;
  }

  return args;
}

function parseExtensions(rawExtensions) {
  const values = rawExtensions
    ? rawExtensions
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean)
    : DEFAULT_EXTENSIONS;

  if (values.length === 0) {
    throw new Error("At least one extension is required");
  }

  for (const extension of values) {
    if (!VALID_EXTENSION_NAME.test(extension)) {
      throw new Error(
        `Invalid extension name "${extension}". Allowed characters: letters, numbers, underscore, hyphen.`,
      );
    }
  }

  return values;
}

async function fetchDatabaseById(metadataSequelize, dbId) {
  const [rows] = await metadataSequelize.query(
    `
      SELECT
        id,
        account_id,
        db_name,
        db_internal_name,
        resource_id,
        status
      FROM db_metadata
      WHERE id = :dbId
      LIMIT 1
    `,
    {
      replacements: { dbId },
    },
  );

  return rows?.[0] ?? null;
}

async function resolveInstanceConnectionString(databaseRow) {
  const vaultPath = constructVaultPath(
    databaseRow.account_id,
    databaseRow.db_internal_name,
    databaseRow.resource_id,
  );

  const vaultData = await getDataFromVault(vaultPath);
  if (!vaultData) {
    throw new Error(
      `Vault data not found for database ${databaseRow.db_internal_name}`,
    );
  }

  const instanceVaultPath =
    vaultData.INSTANCE_VAULT_PATH ||
    constructVaultPathForDedicatedInstance(
      databaseRow.account_id,
      databaseRow.resource_id,
    );

  const instanceConnectionString =
    await getConnectionStringFromVault(instanceVaultPath);

  if (!instanceConnectionString) {
    throw new Error(
      `Instance credentials not found for vault path ${instanceVaultPath}`,
    );
  }

  return {
    instanceConnectionString,
    instanceVaultPath,
    vaultPath,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const dbId = args["db-id"];
  const extensions = parseExtensions(args.extensions);

  if (!dbId) {
    throw new Error(
      "Missing required argument --db-id. Example: node scripts/enable_extensions_for_db_id.js --db-id <uuid> --extensions postgis,postgis_topology",
    );
  }

  let metadataSequelize = null;
  let tenantSequelize = null;

  try {
    metadataSequelize = await createSequelizeInstance(
      appConfig.get("metadata_database_uri"),
      appConfig.get("metadata_database_pool_min"),
      appConfig.get("metadata_database_pool_max"),
    );

    const databaseRow = await fetchDatabaseById(metadataSequelize, dbId);
    if (!databaseRow) {
      throw new Error(`Database not found for id ${dbId}`);
    }

    if (databaseRow.status !== DatabaseStatusEnum.ACTIVE) {
      logger.warn(
        `Database ${databaseRow.db_internal_name} is in status ${databaseRow.status}`,
      );
    }

    const { instanceConnectionString, instanceVaultPath, vaultPath } =
      await resolveInstanceConnectionString(databaseRow);

    const tenantConnectionString = updateDatabaseNameInConnectionString(
      instanceConnectionString,
      databaseRow.db_internal_name,
    );

    logger.info(
      `Enabling extensions for db_id=${databaseRow.id}, db_internal_name=${databaseRow.db_internal_name}, resource_id=${databaseRow.resource_id}, instance_vault_path=${instanceVaultPath}, vault_path=${vaultPath}`,
    );

    tenantSequelize = await createSequelizeInstance(tenantConnectionString);

    for (const extension of extensions) {
      const sql = `CREATE EXTENSION IF NOT EXISTS "${extension}"`;
      logger.info(
        `Executing extension install for ${databaseRow.db_internal_name}: ${sql}`,
      );
      await tenantSequelize.query(sql);
    }

    logger.info(
      `Successfully enabled extensions [${extensions.join(", ")}] for database ${databaseRow.db_internal_name} (${databaseRow.id})`,
    );
  } finally {
    if (tenantSequelize) {
      await tenantSequelize.close().catch(() => {});
    }
    if (metadataSequelize) {
      await metadataSequelize.close().catch(() => {});
    }
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    logger.error(`Failed to enable extensions: ${error.message}`, { error });
    process.exit(1);
  });
```

do this in scripts folder. Command to run it

```sh
node extensions --db-id d2f77cfb-334c-4dd6-9473-41fd0358a0a6 --extensions postgis
```

##
