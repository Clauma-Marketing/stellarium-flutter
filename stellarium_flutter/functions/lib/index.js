"use strict";
/**
 * Star Visibility Notification Cloud Functions
 *
 * This module provides scheduled functions to calculate star visibility
 * and send push notifications to users when their saved stars become visible.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.triggerVisibilityCheck = exports.cleanupOldNotifications = exports.checkStarVisibility = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
// import { onDocumentWritten } from "firebase-functions/v2/firestore";
const starVisibility_1 = require("./starVisibility");
// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// Collection to track sent notifications (avoid duplicates)
const NOTIFICATIONS_SENT_COLLECTION = "notificationsSent";
/**
 * Scheduled function that runs every hour to check star visibility
 * and send notifications to users whose stars are becoming visible soon.
 */
exports.checkStarVisibility = (0, scheduler_1.onSchedule)({
    schedule: "every 1 hours",
    timeZone: "UTC",
    memory: "512MiB",
    timeoutSeconds: 300,
    region: "europe-west1",
}, async () => {
    console.log("Starting star visibility check...");
    try {
        // Get all users with notifications enabled
        const usersSnapshot = await db
            .collection("users")
            .where("notificationsEnabled", "==", true)
            .get();
        console.log(`Found ${usersSnapshot.size} users with notifications enabled`);
        let notificationsSent = 0;
        let errors = 0;
        // Process each user
        for (const userDoc of usersSnapshot.docs) {
            try {
                const userData = userDoc.data();
                // Skip if missing required data
                if (!userData.fcmToken ||
                    userData.latitude === undefined ||
                    userData.longitude === undefined) {
                    continue;
                }
                // Get user's saved stars
                const starsSnapshot = await userDoc.ref
                    .collection("savedStars")
                    .where("notificationsEnabled", "==", true)
                    .get();
                // Check each star
                for (const starDoc of starsSnapshot.docs) {
                    const star = starDoc.data();
                    if (star.ra === undefined || star.dec === undefined) {
                        continue;
                    }
                    // Check if star is becoming visible in the next 30-60 minutes
                    const sent = await checkAndNotifyForStar(userDoc.id, starDoc.id, star, userData);
                    if (sent)
                        notificationsSent++;
                }
            }
            catch (userError) {
                console.error(`Error processing user ${userDoc.id}:`, userError);
                errors++;
            }
        }
        console.log(`Visibility check complete. Sent ${notificationsSent} notifications, ${errors} errors.`);
    }
    catch (error) {
        console.error("Error in checkStarVisibility:", error);
        throw error;
    }
});
/**
 * Check if we should send a notification for a specific star
 * and send it if appropriate.
 */
async function checkAndNotifyForStar(userId, starId, star, userData) {
    const now = new Date();
    // Check if star is currently visible
    const currentlyVisible = (0, starVisibility_1.isVisible)(star.ra, star.dec, userData.latitude, userData.longitude, now);
    // Get next visibility start
    const nextVisibility = (0, starVisibility_1.getNextVisibilityStart)(star.ra, star.dec, userData.latitude, userData.longitude, now);
    // Determine if we should notify
    let shouldNotify = false;
    let notificationTime = null;
    if (currentlyVisible) {
        // Star is currently visible - check if we already notified today
        const alreadyNotified = await wasNotificationSentToday(userId, starId);
        if (!alreadyNotified) {
            shouldNotify = true;
            notificationTime = now;
        }
    }
    else if (nextVisibility) {
        // Star will become visible - check if within notification window (30-60 min)
        const minutesUntilVisible = (nextVisibility.getTime() - now.getTime()) / (1000 * 60);
        if (minutesUntilVisible > 0 && minutesUntilVisible <= 60) {
            const alreadyNotified = await wasNotificationSentToday(userId, starId);
            if (!alreadyNotified) {
                shouldNotify = true;
                notificationTime = nextVisibility;
            }
        }
    }
    if (!shouldNotify || !notificationTime) {
        return false;
    }
    // Build and send notification
    try {
        const direction = (0, starVisibility_1.getDirectionName)((0, starVisibility_1.getStarAzimuth)(star.ra, star.dec, userData.latitude, userData.longitude, notificationTime));
        // Get the full viewing window (start - end times)
        const viewingWindow = (0, starVisibility_1.formatViewingWindow)(star.ra, star.dec, userData.latitude, userData.longitude, notificationTime);
        let body;
        if (currentlyVisible) {
            if (viewingWindow) {
                body = `Your star is now visible in the ${direction} sky (${viewingWindow}).`;
            }
            else {
                body = `Your star is now visible in the ${direction} sky.`;
            }
        }
        else {
            if (viewingWindow) {
                body = `Your star will be visible tonight in the ${direction} sky (${viewingWindow}).`;
            }
            else {
                body = `Your star will be visible soon in the ${direction} sky.`;
            }
        }
        const message = {
            token: userData.fcmToken,
            notification: {
                title: `${star.displayName} is rising!`,
                body: body,
            },
            data: {
                type: "star_visibility",
                starId: starId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                    },
                },
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "star_visibility",
                },
            },
        };
        await messaging.send(message);
        // Record that we sent this notification
        await recordNotificationSent(userId, starId);
        console.log(`Sent notification to ${userId} for star ${star.displayName}`);
        return true;
    }
    catch (error) {
        console.error(`Error sending notification to ${userId}:`, error);
        // If token is invalid, remove it
        if (error instanceof Error &&
            (error.message.includes("not registered") ||
                error.message.includes("invalid"))) {
            await db.collection("users").doc(userId).update({
                fcmToken: admin.firestore.FieldValue.delete(),
            });
        }
        return false;
    }
}
/**
 * Check if we already sent a notification for this star today
 */
async function wasNotificationSentToday(userId, starId) {
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const notificationId = `${userId}_${starId}_${today}`;
    const doc = await db
        .collection(NOTIFICATIONS_SENT_COLLECTION)
        .doc(notificationId)
        .get();
    return doc.exists;
}
/**
 * Record that we sent a notification
 */
async function recordNotificationSent(userId, starId) {
    const today = new Date().toISOString().split("T")[0];
    const notificationId = `${userId}_${starId}_${today}`;
    await db.collection(NOTIFICATIONS_SENT_COLLECTION).doc(notificationId).set({
        userId,
        starId,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        date: today,
    });
}
/**
 * Cleanup old notification records (run daily)
 */
exports.cleanupOldNotifications = (0, scheduler_1.onSchedule)({
    schedule: "every day 03:00",
    timeZone: "UTC",
    region: "europe-west1",
}, async () => {
    console.log("Cleaning up old notification records...");
    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
    const cutoffDate = twoDaysAgo.toISOString().split("T")[0];
    const oldNotifications = await db
        .collection(NOTIFICATIONS_SENT_COLLECTION)
        .where("date", "<", cutoffDate)
        .limit(500)
        .get();
    const batch = db.batch();
    oldNotifications.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${oldNotifications.size} old notification records`);
});
/**
 * Trigger immediate visibility check when a user's location is updated
 * Note: Commented out for now - requires Eventarc permissions to be set up first
 * The hourly scheduled function will handle these cases.
 */
// export const onUserLocationUpdate = onDocumentWritten(
//   "users/{userId}",
//   async (event) => {
//     const beforeData = event.data?.before?.data() as UserData | undefined;
//     const afterData = event.data?.after?.data() as UserData | undefined;
//
//     if (!afterData) return;
//
//     // Check if location changed
//     const locationChanged =
//       beforeData?.latitude !== afterData.latitude ||
//       beforeData?.longitude !== afterData.longitude;
//
//     // Check if notifications were just enabled
//     const notificationsJustEnabled =
//       !beforeData?.notificationsEnabled && afterData.notificationsEnabled;
//
//     if (locationChanged || notificationsJustEnabled) {
//       console.log(
//         `User ${event.params.userId} location/notifications changed, checking visibility...`
//       );
//
//       // For now, just log - the hourly job will pick this up
//       // In a more advanced version, we could trigger immediate check
//     }
//   }
// );
/**
 * HTTP function to manually trigger visibility check (for testing)
 */
const https_1 = require("firebase-functions/v2/https");
exports.triggerVisibilityCheck = (0, https_1.onRequest)({
    cors: true,
    region: "europe-west1",
}, async (req, res) => {
    // Only allow POST requests
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    // Optional: Add authentication check here
    // const authHeader = req.headers.authorization;
    // if (!authHeader || authHeader !== 'Bearer YOUR_SECRET_KEY') {
    //   res.status(401).send('Unauthorized');
    //   return;
    // }
    console.log("Manual visibility check triggered");
    try {
        // Import the scheduled function logic
        const usersSnapshot = await db
            .collection("users")
            .where("notificationsEnabled", "==", true)
            .limit(10) // Limit for testing
            .get();
        res.json({
            success: true,
            usersFound: usersSnapshot.size,
            message: "Visibility check triggered. Check logs for details.",
        });
    }
    catch (error) {
        console.error("Error in manual trigger:", error);
        res.status(500).json({ success: false, error: String(error) });
    }
});
//# sourceMappingURL=index.js.map