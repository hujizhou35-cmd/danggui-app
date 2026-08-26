import { defineConfig, globalIgnores } from 'eslint/config';
import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTs from 'eslint-config-next/typescript';

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // Vinext currently renders Next Link transitions unreliably in this project;
    // plain anchors preserve real, keyboard-operable navigation.
    rules: { '@next/next/no-html-link-for-pages': 'off' },
  },
  globalIgnores(['.next/**', 'out/**', 'build/**', 'dist/**', 'work/**', 'qa/**', 'next-env.d.ts']),
]);

export default eslintConfig;
