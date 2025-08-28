import { fileURLToPath } from "url";
import path, { dirname } from "path";
import swaggerJsdoc from "swagger-jsdoc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const swaggerOptions = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Bhandara API",
      version: "1.0.0",
    },
    servers: [{ url: "/api" }],
  },
  apis: [path.join(__dirname, "../rout@/*.ts")],
};

export const swaggerSpec = swaggerJsdoc(swaggerOptions);
