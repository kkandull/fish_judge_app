// functions/index.js
//
// Cloud Functions for Firebase — FCM 알림 자동 전송
//
// 트리거:
//   1. 새 댓글 작성 → 게시글 작성자에게 알림
//   2. 새 좋아요 → 게시글 작성자에게 알림 (5개마다 묶음)

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. 새 댓글 → 게시글 작성자에게 알림
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.onCommentCreated = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const comment = snap.data();
    const { postId } = event.params;

    try {
      // 1. 게시글 조회
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await postRef.get();
      if (!postSnap.exists) {
        logger.warn(`Post ${postId} not found`);
        return;
      }

      const post = postSnap.data();
      const authorUid = post.uid;

      // 2. 본인 댓글이면 알림 X (자기 글에 자기 댓글)
      if (comment.uid === authorUid) {
        logger.info(`Self-comment, skip notification`);
        return;
      }

      // 3. 게시글 작성자 FCM 토큰 조회
      const userRef = db.collection("users").doc(authorUid);
      const userSnap = await userRef.get();
      if (!userSnap.exists) {
        logger.warn(`User ${authorUid} not found`);
        return;
      }

      const fcmToken = userSnap.data().fcmToken;
      if (!fcmToken) {
        logger.warn(`No FCM token for ${authorUid}`);
        return;
      }

      // 4. 알림 전송
      const message = {
        token: fcmToken,
        notification: {
          title: `💬 ${comment.nickname}님의 댓글`,
          body: comment.body.length > 50
            ? comment.body.substring(0, 50) + "..."
            : comment.body,
        },
        data: {
          type: "comment",
          postId: postId,
          postTitle: post.title || "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await messaging.send(message);
      logger.info(`✅ 댓글 알림 전송: ${response}`);
    } catch (error) {
      logger.error("❌ 댓글 알림 실패:", error);
    }
  }
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2. 새 좋아요 → 5개마다 묶음 알림 (스팸 방지)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.onLikeCreated = onDocumentCreated(
  "posts/{postId}/likes/{userId}",
  async (event) => {
    const { postId, userId } = event.params;

    try {
      // 1. 게시글 조회
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await postRef.get();
      if (!postSnap.exists) return;

      const post = postSnap.data();
      const authorUid = post.uid;

      // 2. 본인 좋아요면 스킵
      if (userId === authorUid) return;

      // 3. 새 likeCount 조회 (트랜잭션 후 값)
      const newLikeCount = post.likeCount || 0;

      // 4. 5의 배수 또는 1일 때만 알림 (1, 5, 10, 15, 20, ...)
      const shouldNotify = newLikeCount === 1 || newLikeCount % 5 === 0;
      if (!shouldNotify) {
        logger.info(`Like count ${newLikeCount}, skip notification`);
        return;
      }

      // 5. 작성자 FCM 토큰
      const userRef = db.collection("users").doc(authorUid);
      const userSnap = await userRef.get();
      if (!userSnap.exists) return;

      const fcmToken = userSnap.data().fcmToken;
      if (!fcmToken) return;

      // 6. 알림 전송
      const message = {
        token: fcmToken,
        notification: {
          title: `❤️ 좋아요 ${newLikeCount}개`,
          body: `"${post.title}" 게시글에 좋아요가 달렸어요`,
        },
        data: {
          type: "like",
          postId: postId,
          likeCount: String(newLikeCount),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
          },
        },
      };

      const response = await messaging.send(message);
      logger.info(`✅ 좋아요 알림 전송: ${response}`);
    } catch (error) {
      logger.error("❌ 좋아요 알림 실패:", error);
    }
  }
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// (선택) 오래된 FCM 토큰 정리 — 추후 추가 가능
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━