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
    // For emulator, we can use a dummy service account
    admin.initializeApp({
      projectId: 'likha-pet-dev',
    });
  } else {
    // For production, use service account from credentials file
    const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
      path.join(__dirname, '../../firebase-credentials.json');
    
    admin.initializeApp({
      credential: admin.credential.cert(credentialsPath),
      projectId: process.env.FIREBASE_PROJECT_ID || 'likha-pet-prod',
    });
  }

  console.log('✓ Firestore initialized');
}

export function getFirestore(): admin.firestore.Firestore {
  return admin.firestore();
}
