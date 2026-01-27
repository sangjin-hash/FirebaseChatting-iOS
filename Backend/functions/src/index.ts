/**
 * Firebase Functions for FirebaseChatting App
 *
 * Functions:
 * 1. createUserDocument - Auth Trigger: 새 사용자 생성 시 Firestore에 자동 저장
 * 2. getFriends - Callable: 친구 프로필 목록 조회
 * 3. getUserBatch - Callable: 채팅방별 상대방 프로필 조회
 * 4. searchUsers - Callable: 닉네임 prefix 검색
 * 5. addFriend - Callable: 친구 추가 (양방향)
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

// Firebase Admin 초기화
admin.initializeApp();

// Firestore 참조
const db = admin.firestore();

/**
 * 프로필 인터페이스 (API 응답용)
 */
interface Profile {
  id: string;
  nickname: string | null;
  profilePhotoUrl: string | null;
}

/**
 * 사용자 정보 인터페이스 (Firestore 문서 구조)
 */
interface UserInfo {
  id: string;
  nickname: string | null;
  profilePhotoUrl: string | null;
  friendIds: string[];
  chatRooms: string[];
}

/**
 * UserInfo에서 Profile 추출
 * @param {UserInfo} user - 사용자 정보
 * @return {Profile} 프로필 정보
 */
function toProfile(user: UserInfo): Profile {
  return {
    id: user.id,
    nickname: user.nickname,
    profilePhotoUrl: user.profilePhotoUrl,
  };
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
 * 친구 프로필 목록 조회
 *
 * Callable Function
 *
 * @param friendIds - 조회할 친구 ID 목록
 * @returns 친구 프로필 목록
 */
export const getFriends = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Login required"
      );
    }

    const friendIds = data.friendIds as string[];

    if (!friendIds || !Array.isArray(friendIds)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "friendIds is required"
      );
    }

    logger.info(`Getting ${friendIds.length} friends`);

    try {
      const profiles: Profile[] = [];

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
              const userData = doc.data() as UserInfo;
              profiles.push(toProfile(userData));
            }
          });
        }
      }

      logger.info(`Found ${profiles.length} friend profiles`);

      return {profiles};
    } catch (error) {
      logger.error("Failed to get friends", error);
      throw new functions.https.HttpsError("internal", "Failed to get friends");
    }
  });

/**
 * 채팅방별 상대방 프로필 조회
 *
 * Callable Function
 *
 * - 1:1 채팅방 (D_userId1_userId2): chatRoomId에서 상대방 userId 추출
 * - 1:N 채팅방 (G_randomId): chatRooms/{id} 문서의 activeUsers에서 추출
 *
 * @param chatRooms - 조회할 채팅방 ID 목록
 * @returns 채팅방별 상대방 프로필 맵
 */
export const getUserBatch = functions
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
    const chatRoomIds = data.chatRooms as string[];

    if (!chatRoomIds || !Array.isArray(chatRoomIds)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "chatRooms is required"
      );
    }

    logger.info(`Getting user batch for ${chatRoomIds.length} chat rooms`);

    try {
      const profiles: { [chatRoomId: string]: Profile } = {};
      const userIdsToFetch: Set<string> = new Set();
      const chatRoomUserMap: { [chatRoomId: string]: string } = {};

      // 1. 채팅방 ID에서 상대방 userId 추출
      for (const chatRoomId of chatRoomIds) {
        if (chatRoomId.startsWith("D_")) {
          // 1:1 채팅방: D_userId1_userId2
          const parts = chatRoomId.substring(2).split("_");
          const otherUserId = parts.find((id) => id !== userId);
          if (otherUserId) {
            userIdsToFetch.add(otherUserId);
            chatRoomUserMap[chatRoomId] = otherUserId;
          }
        }
      }

      // 2. 1:N 채팅방은 Firestore에서 activeUsers 조회
      const groupChatRoomIds = chatRoomIds.filter(
        (id) => id.startsWith("G_")
      );
      for (const chatRoomId of groupChatRoomIds) {
        const chatRoomDoc = await db
          .collection("chatRooms").doc(chatRoomId).get();
        if (chatRoomDoc.exists) {
          const chatRoomData = chatRoomDoc.data();
          type ActiveUsersMap = { [key: string]: unknown };
          const activeUsers =
            chatRoomData?.activeUsers as ActiveUsersMap || {};
          const otherUserIds = Object.keys(activeUsers)
            .filter((id) => id !== userId);
          if (otherUserIds.length > 0) {
            // 첫 번째 사용자를 대표로 사용
            userIdsToFetch.add(otherUserIds[0]);
            chatRoomUserMap[chatRoomId] = otherUserIds[0];
          }
        }
      }

      // 3. 사용자 프로필 일괄 조회
      const userIdsArray = Array.from(userIdsToFetch);
      const userProfiles: { [userId: string]: Profile } = {};

      for (let i = 0; i < userIdsArray.length; i += 30) {
        const batch = userIdsArray.slice(i, i + 30);
        if (batch.length > 0) {
          const userDocs = await db
            .collection("users")
            .where(admin.firestore.FieldPath.documentId(), "in", batch)
            .get();

          userDocs.forEach((doc) => {
            if (doc.exists) {
              const userData = doc.data() as UserInfo;
              userProfiles[doc.id] = toProfile(userData);
            }
          });
        }
      }

      // 4. 채팅방별 프로필 매핑
      for (const [chatRoomId, otherUserId] of Object.entries(chatRoomUserMap)) {
        if (userProfiles[otherUserId]) {
          profiles[chatRoomId] = userProfiles[otherUserId];
        }
      }

      const count = Object.keys(profiles).length;
      logger.info(`Found profiles for ${count} chat rooms`);

      return {profiles};
    } catch (error) {
      logger.error("Failed to get user batch", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to get user batch"
      );
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

      const users: Profile[] = [];
      snapshot.forEach((doc) => {
        const userData = doc.data() as UserInfo;
        // 본인 제외
        if (userData.id !== userId) {
          users.push(toProfile(userData));
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
