import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Shared web/admin config — placeholders until FlutterFire / ops fill values. */
export const firebaseConfig = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, '../../web_config.json'), 'utf8'),
);

export const projectId = firebaseConfig.projectId;
export const storageBucket = firebaseConfig.storageBucket;
