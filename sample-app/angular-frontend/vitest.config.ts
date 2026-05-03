import { defineConfig } from 'vitest/config';

const isCi = Boolean(process.env.CI);

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['src/test-setup.ts'],
    // TestBed is global; running multiple spec files in one worker causes
    // "already been instantiated" in CI when files configure TestBed in parallel.
    pool: 'forks',
    reporters: isCi
      ? [
          'default',
          'github-actions',
          [
            'junit',
            {
              outputFile: 'reports/vitest-junit.xml',
              addFileAttribute: true,
            },
          ],
        ]
      : ['default'],
  },
});
