import path, { dirname } from "path";
import swaggerJsdoc from "swagger-jsdoc";

export const swaggerOptions = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Bhandara API",
      version: "1.0.0",
    },
    servers: [{ url: "/api" }],
    security: [{ SessionCookieAuth: [] }],
  },
  apis: [
    path.join(__dirname, '../routes/*.route.{ts,js}'),
    path.join(__dirname, './openapi/**/*.{ts,js}'),
  ],
};

export const swaggerSpec = swaggerJsdoc(swaggerOptions);
