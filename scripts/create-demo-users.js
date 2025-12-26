const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function createDemoUsers() {
  const users = [
    {
      email: 'student@putramate.com',
      password: 'Student123!',
      displayName: 'Demo Student',
      role: 'student'
    },
    {
      email: 'counsellor@putramate.com',
      password: 'Counsellor123!',
      displayName: 'Dr. Sarah Wong',
      role: 'counsellor'
    },
    {
      email: 'admin@putramate.com',
      password: 'Admin123!',
      displayName: 'Admin User',
      role: 'admin'
    }
  ];

  console.log('Creating demo users...\n');

  for (const userData of users) {
    try {
      // Create Firebase Auth user
      const userRecord = await auth.createUser({
        email: userData.email,
        password: userData.password,
        displayName: userData.displayName,
        emailVerified: true
      });

      console.log(`✓ Created Auth user: ${userData.email} (${userRecord.uid})`);

      // Create Firestore profile
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: userData.email,
        displayName: userData.displayName,
        role: userData.role,
        photoUrl: null
      });

      console.log(`✓ Created Firestore profile for ${userData.email}\n`);

    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        console.log(`⚠ User ${userData.email} already exists, skipping...\n`);
      } else {
        console.error(`✗ Error creating ${userData.email}:`, error.message, '\n');
      }
    }
  }

  console.log('\n=== Demo Users Created ===');
  console.log('Student: student@putramate.com / Student123!');
  console.log('Counsellor: counsellor@putramate.com / Counsellor123!');
  console.log('Admin: admin@putramate.com / Admin123!');
  console.log('\nYou can now login with these credentials.');
}

createDemoUsers()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
