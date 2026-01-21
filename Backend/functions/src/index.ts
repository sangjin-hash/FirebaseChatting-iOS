/**
 * Firebase Functions for FirebaseChatting App
 *
 * Functions:
 * 1. createUserDocument - Auth Trigger: 새 사용자 생성 시 Firestore에 자동 저장
 * 2. getUserWithFriends - Callable: 사용자 정보 + 친구목록 조회
 * 3. searchUsers - Callable: 닉네임 prefix 검색
 * 4. addFriend - Callable: 친구 추가 (양방향)
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

// Firebase Admin 초기화
admin.initializeApp();

// Firestore 참조
const db = admin.firestore();

/**
 * 사용자 정보 인터페이스
 */
interface UserInfo {
  id: string;
  nickname: string | null;
  profilePhotoUrl: string | null;
  friendIds: string[];
  chatRooms: string[];
}

/**
 * 새 사용자 생성 시 Firestore에 자동 저장
 *
 * Auth Trigger (onCreate)
 *
 * Firebase Auth에 새 사용자가 생성되면 자동으로 백그라운드에서 실행됩니다.
 * Google 로그인의 경우 displayName과 photoURL을 자동으로 가져옵니다.
 */
export const createUserDocument = functions
  .region("asia-northeast3")
  .auth.user()
  .onCreate(async (user) => {
    const userId = user.uid;

    logger.info(`Creating Firestore document for new user: ${userId}`);

    try {
      // Google 로그인 정보 추출
      const displayName = user.displayName || null;
      const photoURL = user.photoURL || null;

      const newUserDoc: UserInfo = {
        id: userId,
        nickname: displayName,
        profilePhotoUrl: photoURL,
        friendIds: [],
        chatRooms: [],
      };

      // Firestore에 사용자 정보 저장
      await db.collection("users").doc(userId).set(newUserDoc);

      logger.info(`Firestore document created for user: ${userId}`, {
        nickname: displayName,
        hasPhoto: !!photoURL,
      });
    } catch (error) {
      logger.error(
        `Failed to create Firestore document for user ${userId}:`,
        error
      );
      throw error; // 백그라운드 함수이므로 에러를 throw하여 재시도 가능
    }
  });

/**
 * 사용자 정보 + 친구목록 조회
 *
 * Callable Function
 *
 * @param userId - 조회할 사용자 ID
 * @returns 사용자 정보와 친구 목록
 */
export const getUserWithFriends = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Login required"
      );
    }

    const userId = context.auth.uid;

    logger.info(`Getting user with friends: ${userId}`);

    try {
      // 1. 사용자 문서 조회
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "User not found");
      }

      const user = userDoc.data() as UserInfo;

      // 2. 친구 목록 조회 (30개씩 배치)
      const friendIds = user.friendIds || [];
      const friends: UserInfo[] = [];

      // Firestore 'in' 쿼리는 최대 30개까지만 지원
      for (let i = 0; i < friendIds.length; i += 30) {
        const batch = friendIds.slice(i, i + 30);
        if (batch.length > 0) {
          const friendDocs = await db
            .collection("users")
            .where(admin.firestore.FieldPath.documentId(), "in", batch)
            .get();

          friendDocs.forEach((doc) => {
            if (doc.exists) {
              friends.push(doc.data() as UserInfo);
            }
          });
        }
      }

      logger.info(`Found ${friends.length} friends for user: ${userId}`);

      return {user, friends};
    } catch (error) {
      logger.error(`Failed to get user with friends: ${userId}`, error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", "Failed to get user");
    }
  });

/**
 * 닉네임 prefix 검색
 *
 * Callable Function
 *
 * @param query - 검색할 닉네임 prefix
 * @param userId - 본인 ID (검색 결과에서 제외)
 * @returns 검색된 사용자 목록
 */
export const searchUsers = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Login required"
      );
    }

    const query = data.query as string;
    const userId = context.auth.uid;

    if (!query) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "query is required"
      );
    }

    logger.info(`Searching users with query: ${query}`);

    try {
      // Prefix 검색 (앞글자부터 검색)
      const snapshot = await db
        .collection("users")
        .where("nickname", ">=", query)
        .where("nickname", "<", query + "\uf8ff")
        .limit(20)
        .get();

      const users: UserInfo[] = [];
      snapshot.forEach((doc) => {
        const user = doc.data() as UserInfo;
        // 본인 제외
        if (user.id !== userId) {
          users.push(user);
        }
      });

      logger.info(`Found ${users.length} users for query: ${query}`);

      return {users};
    } catch (error) {
      logger.error(`Failed to search users: ${query}`, error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to search users"
      );
    }
  });

/**
 * 친구 추가 (양방향)
 *
 * Callable Function
 *
 * @param userId - 요청자 ID
 * @param friendId - 추가할 친구 ID
 * @returns 성공 여부
 */
export const addFriend = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Login required"
      );
    }

    const userId = context.auth.uid;
    const friendId = data.friendId as string;

    if (!friendId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "friendId is required"
      );
    }

    // 본인 추가 방지
    if (userId === friendId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Cannot add yourself as a friend"
      );
    }

    logger.info(`Adding friend: ${userId} -> ${friendId}`);

    try {
      const userRef = db.collection("users").doc(userId);
      const friendRef = db.collection("users").doc(friendId);

      // Transaction으로 양방향 친구 추가
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        const friendDoc = await transaction.get(friendRef);

        if (!userDoc.exists) {
          throw new functions.https.HttpsError("not-found", "User not found");
        }

        if (!friendDoc.exists) {
          throw new functions.https.HttpsError("not-found", "Friend not found");
        }

        const userData = userDoc.data() as UserInfo;

        // 이미 친구인지 확인
        if (userData.friendIds?.includes(friendId)) {
          throw new functions.https.HttpsError(
            "already-exists",
            "Already friends"
          );
        }

        // 양방향 친구 추가
        transaction.update(userRef, {
          friendIds: admin.firestore.FieldValue.arrayUnion(friendId),
        });

        transaction.update(friendRef, {
          friendIds: admin.firestore.FieldValue.arrayUnion(userId),
        });
      });

      logger.info(`Friend added successfully: ${userId} <-> ${friendId}`);

      return {success: true};
    } catch (error) {
      logger.error(`Failed to add friend: ${userId} -> ${friendId}`, error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", "Failed to add friend");
    }
  });
