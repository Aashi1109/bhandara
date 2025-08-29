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
  },
  apis: [path.join(__dirname, "../rout@/*.ts")],
};

export const swaggerSpec = swaggerJsdoc(swaggerOptions);
