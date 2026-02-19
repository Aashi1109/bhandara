const { defineConfig } = require("eslint/config");
const expoConfig = require("eslint-config-expo/flat");
const prettierConfig = require("eslint-config-prettier");

module.exports = defineConfig([
  expoConfig,
  {
    rules: {
      //* Safety & Bugs
      "no-console": "warn",
      "no-duplicate-imports": "error",
      "no-var": "error",
      "prefer-const": "error",
      "eqeqeq": ["error", "always", { "null": "ignore" }],
      "no-useless-concat": "error",
      "no-useless-return": "error",
      //* React — expo config already includes react-hooks rules
      "react/display-name": "warn",
      //* Metro handles module resolution — standard node resolver produces false positives for RN packages
      "import/no-unresolved": "off",
      //* Style
      "prefer-template": "warn",
      "prefer-arrow-callback": "warn",
    },
  },
  {
    files: ["**/*.ts", "**/*.tsx"],
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "warn",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-non-null-assertion": "warn",
      "@typescript-eslint/consistent-type-imports": [
        "warn",
        { prefer: "type-imports" },
      ],
    },
  },
  prettierConfig,
  {
    ignores: [
      "node_modules/**",
      ".expo/**",
      "dist/**",
      "android/**",
      "ios/**",
      "coverage/**",
      "*.config.{js,ts,mjs,cjs}",
      "babel.config.js",
      "metro.config.js",
      "scripts/**",
      ".tamagui/**",
    ],
  },
]);
