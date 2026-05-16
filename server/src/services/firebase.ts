import * as admin from 'firebase-admin';
import * as fs from 'fs';

/**
 * Initialize Firebase Admin SDK
 * 
 * For development: Uses Firebase Emulator (configured via FIRESTORE_EMULATOR_HOST env var)
 * For production: Uses service account credentials from GOOGLE_APPLICATION_CREDENTIALS
 */
export function initializeFirebase(): void {
  // Check if already initialized
  if (admin.apps.length > 0) {
    console.log('✓ Firebase already initialized');
    return;
  }

  const configuredEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
  const hasCredentialsPath = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const isProduction = process.env.NODE_ENV === 'production';
  const shouldUseEmulator =
    !!configuredEmulatorHost || (!isProduction && !hasCredentialsPath);

  if (shouldUseEmulator) {
    const emulatorHost = configuredEmulatorHost || '127.0.0.1:8090';
    process.env.FIRESTORE_EMULATOR_HOST = emulatorHost;
    console.log(`✓ Using Firebase Emulator at ${emulatorHost}`);
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'demo-likha-pet',
    });
  } else {
    // On Cloud Run / GCE: Application Default Credentials are picked up automatically.
    // Locally with a real project: set GOOGLE_APPLICATION_CREDENTIALS to the key file path.
    const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (credentialsPath) {
      const serviceAccount = JSON.parse(
        fs.readFileSync(credentialsPath, 'utf8')
      ) as admin.ServiceAccount;
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: process.env.FIREBASE_PROJECT_ID || 'paksi-game-beta',
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: process.env.FIREBASE_PROJECT_ID || 'paksi-game-beta',
      });
    }
  }

  console.log('✓ Firestore initialized');
}

export function getFirestore(): admin.firestore.Firestore {
  return admin.firestore();
}
