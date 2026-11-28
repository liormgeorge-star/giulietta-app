// Bundled by scripts/vendor.sh into www/vendor/firebase.js (exposes window.FB).
export { initializeApp } from 'firebase/app';
export { initializeAuth, indexedDBLocalPersistence, browserLocalPersistence, onAuthStateChanged, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, sendPasswordResetEmail, signOut, updateProfile, connectAuthEmulator } from 'firebase/auth';
export { initializeFirestore, persistentLocalCache, persistentMultipleTabManager, doc, setDoc, getDoc, updateDoc, deleteDoc,
  collection, onSnapshot, arrayUnion, arrayRemove, deleteField, writeBatch, connectFirestoreEmulator } from 'firebase/firestore';
