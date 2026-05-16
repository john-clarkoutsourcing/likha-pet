import * as admin from 'firebase-admin';
import * as path from 'path';

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

  const isEmulator = process.env.FIRESTORE_EMULATOR_HOST !== undefined;

  if (isEmulator) {
    console.log(`✓ Using Firebase Emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`);
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'demo-likha-pet',
    });
  } else {
    // On Cloud Run / GCE: Application Default Credentials are picked up automatically.
    // Locally with a real project: set GOOGLE_APPLICATION_CREDENTIALS to the key file path.
    const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (credentialsPath) {
      admin.initializeApp({
        credential: admin.credential.cert(credentialsPath),
        projectId: process.env.FIREBASE_PROJECT_ID || 'paksi-game-beta',
      });
    } else {
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'paksi-game-beta',
      });
    }
  }

  console.log('✓ Firestore initialized');
}

export function getFirestore(): admin.firestore.Firestore {
  return admin.firestore();
}
