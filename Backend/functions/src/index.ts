/**
 * Firebase Functions for FirebaseChatting App
 *
 * Functions:
 * 1. login - HTTP Callable: 로그인 시 사용자 정보 생성/업데이트
 */

import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// Firebase Admin 초기화
admin.initializeApp();

// 전역 옵션 설정
setGlobalOptions({
  maxInstances: 10,
  region: "asia-northeast3", // 서울 리전
});

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
 * 로그인 시 사용자 정보 생성/업데이트
 *
 * HTTP Callable Function
 *
 * 요청 파라미터:
 * - nickname: string | null (선택)
 * - profilePhotoUrl: string | null (선택)
 *
 * 응답:
 * - success: boolean
 * - message: string
 * - user: UserInfo
 */
export const login = onCall(async (request) => {
  // 인증 확인
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "User must be authenticated to login"
    );
  }

  const userId = request.auth.uid;
  const {nickname, profilePhotoUrl} = request.data;

  // 빈 문자열을 null로 변환
  const normalizedNickname = nickname === "" ? null : nickname;
  const normalizedProfilePhotoUrl = profilePhotoUrl === "" ?
    null : profilePhotoUrl;

  logger.info(`Login attempt for user: ${userId}`, {
    userId,
    hasNickname: !!normalizedNickname,
    hasProfilePhotoUrl: !!normalizedProfilePhotoUrl,
  });

  try {
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      // 문서가 없으면 생성 (최초 로그인)
      const newUserDoc: UserInfo = {
        id: userId,
        nickname: normalizedNickname,
        profilePhotoUrl: normalizedProfilePhotoUrl,
        chatRooms: [],
      };

      await userRef.set(newUserDoc);
      logger.info(`New user created: ${userId}`);

      return {
        success: true,
        message: "User created successfully",
        user: newUserDoc,
      };
    } else {
      // 문서가 있으면 구글 계정 정보 업데이트 (재로그인)
      const updateData: Partial<UserInfo> = {};

      // nickname과 profilePhotoUrl은 구글 계정에서 변경될 수 있으므로 항상 업데이트
      if (normalizedNickname !== undefined) {
        updateData.nickname = normalizedNickname;
      }

      if (normalizedProfilePhotoUrl !== undefined) {
        updateData.profilePhotoUrl = normalizedProfilePhotoUrl;
      }

      await userRef.update(updateData);
      logger.info(`User profile updated: ${userId}`);

      const updatedDoc = await userRef.get();
      const updatedUser = updatedDoc.data() as UserInfo;

      return {
        success: true,
        message: "User profile updated successfully",
        user: updatedUser,
      };
    }
  } catch (error) {
    logger.error(`Error during login: ${error}`);
    throw new HttpsError("internal", "Failed to process login");
  }
});
