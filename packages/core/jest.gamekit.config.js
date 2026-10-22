/** GameKit tests: native ES modules (luau-web uses top-level await), run with --experimental-vm-modules. */
import base from './jest.config.js';

export default {
  ...base,
  roots: ['<rootDir>/src/gamekit'],
  testPathIgnorePatterns: ['/node_modules/'],
};
