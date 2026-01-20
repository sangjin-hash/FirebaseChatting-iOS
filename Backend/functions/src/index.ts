/**
 * Firebase Functions for FirebaseChatting App
 *
 * Functions:
 * 1. createUserDocument - Auth Trigger: 새 사용자 생성 시 Firestore에 자동 저장
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
