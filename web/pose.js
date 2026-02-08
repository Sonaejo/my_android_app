// web/pose.js
// MediaPipe Tasks Vision 0.10.3 を利用
import {
  PoseLandmarker,
  FilesetResolver
} from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.3";

let videoEl = null;
let stream = null;
let landmarker = null;
let running = false;
let rafId = 0;
let selfieMode = true; // フロントカメラ想定（見た目をミラー）

// Flutter側の window.addEventListener と衝突しない専用名にする
const EVT_POSE = "pose";
const EVT_ERR = "pose_error";

// --- しきい値（Flutter側のロジック方針に合わせてやや厳しめ） ---
const CONF = {
  minPoseDetectionConfidence: 0.7,
  minPosePresenceConfidence: 0.6,
  minTrackingConfidence: 0.7,
};

function logOnce(msg) { console.log("[pose.js]", msg); }

// 連打防止（同じエラーを何度も投げない）
let lastErrSig = "";
let lastErrAt = 0;

function dispatchError(message, extra) {
  const detail = {
    message: String(message ?? "unknown error"),
    ...(extra ? { extra } : {}),
  };

  // シグネチャ
  const sig = `${detail.message}|${extra?.code ?? ""}|${extra?.name ?? ""}`;
  const now = Date.now();

  // 同一エラーは 1秒以内に再送しない
  if (sig === lastErrSig && (now - lastErrAt) < 1000) return;
  lastErrSig = sig;
  lastErrAt = now;

  window.dispatchEvent(new CustomEvent(EVT_ERR, { detail }));
}

function isPermissionDeniedError(e) {
  const name = e?.name || "";
  const msg = String(e?.message || "").toLowerCase();
  return (
    name === "NotAllowedError" ||
    name === "PermissionDeniedError" ||
    msg.includes("permission") && msg.includes("denied") ||
    msg.includes("notallowederror")
  );
}

// ---- MediaPipe の初期化 ---------------------------------------------------
async function initLandmarker() {
  if (landmarker) return landmarker;

  const fileset = await FilesetResolver.forVisionTasks(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.3/wasm"
  );

  landmarker = await PoseLandmarker.createFromOptions(fileset, {
    baseOptions: {
      modelAssetPath:
        "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.3/pose_landmarker_lite.task",
    },
    runningMode: "VIDEO",
    numPoses: 1,
    minPoseDetectionConfidence: CONF.minPoseDetectionConfidence,
    minPosePresenceConfidence: CONF.minPosePresenceConfidence,
    minTrackingConfidence: CONF.minTrackingConfidence,
    outputSegmentationMasks: false,
  });

  return landmarker;
}

// ---- カメラ開始 -----------------------------------------------------------
async function startCamera() {
  if (stream) return stream;

  videoEl = document.getElementById("cam");
  if (!videoEl) throw new Error("video element #cam not found");

  const constraints = {
    audio: false,
    video: {
      facingMode: selfieMode ? "user" : "environment",
      width: { ideal: 1280 }, height: { ideal: 720 },
      frameRate: { ideal: 30, max: 60 },
    },
  };

  try {
    stream = await navigator.mediaDevices.getUserMedia(constraints);
  } catch (e) {
    // ✅ 権限拒否は “permission_denied” として通知して止める
    if (isPermissionDeniedError(e)) {
      dispatchError("camera permission denied", { code: "permission_denied", name: e?.name });
      throw e;
    }
    dispatchError(e?.message ?? e, { code: "getUserMedia_failed", name: e?.name });
    throw e;
  }

  videoEl.srcObject = stream;
  videoEl.classList.toggle("mirror", selfieMode);

  videoEl.playsInline = true;
  videoEl.muted = true;

  await videoEl.play();
  document.getElementById("loading")?.remove();

  return stream;
}

// ---- 座標を 0..1 正規化して Flutter へブリッジ（12点だけ渡す） ----------
function dispatchPose(landmarks) {
  const idx = {
    leftShoulder: 11,
    rightShoulder: 12,
    leftElbow: 13,
    rightElbow: 14,
    leftWrist: 15,
    rightWrist: 16,
    leftHip: 23,
    rightHip: 24,
    leftKnee: 25,
    rightKnee: 26,
    leftAnkle: 27,
    rightAnkle: 28,
  };

  const obj = {};
  Object.entries(idx).forEach(([name, i]) => {
    const lm = landmarks[i];
    if (!lm) return;
    const x = Math.min(1, Math.max(0, lm.x));
    const y = Math.min(1, Math.max(0, lm.y));
    obj[name] = { x, y };
  });

  window.dispatchEvent(new CustomEvent(EVT_POSE, { detail: { landmarks: obj } }));
}

// 無効フレームを通知（Flutter側で「欠損フレーム」として扱わせる）
function dispatchInvalid() {
  window.dispatchEvent(new CustomEvent(EVT_POSE, { detail: { landmarks: {} } }));
}

// ---- メインループ ---------------------------------------------------------
function loop() {
  if (!running || !videoEl || !landmarker) return;

  try {
    const nowMs = performance.now();
    const result = landmarker.detectForVideo(videoEl, nowMs);

    if (result && result.landmarks && result.landmarks.length > 0) {
      const lms = result.landmarks[0];

      let okCount = 0;
      for (const p of lms) {
        const vis = (typeof p.visibility === "number") ? p.visibility : 1.0;
        if (vis >= 0.5) okCount++;
      }
      if (okCount >= 10) {
        dispatchPose(lms);
      } else {
        dispatchInvalid();
      }
    } else {
      dispatchInvalid();
    }
  } catch (e) {
    // ✅ 例外が出ても無限にエラーを出さない（dispatchErrorが1秒間隔に抑制）
    dispatchError(e?.message ?? e, { code: "detect_failed", name: e?.name });
    dispatchInvalid();
  }

  rafId = requestAnimationFrame(loop);
}

// ---- 外部公開API（Flutterから呼ぶ） ---------------------------------------
async function poseStart() {
  if (running) return;

  try {
    await initLandmarker();
    await startCamera();

    running = true;
    loop();
    logOnce("poseStart: ok");
  } catch (e) {
    console.error(e);

    // ✅ 権限拒否のときは running のままにしない（ループを回さない）
    running = false;
    cancelAnimationFrame(rafId);

    if (isPermissionDeniedError(e)) {
      dispatchError("camera permission denied", { code: "permission_denied", name: e?.name });
    } else {
      dispatchError(e?.message ?? e, { code: "poseStart_failed", name: e?.name });
    }
  }
}

async function poseStop() {
  running = false;
  cancelAnimationFrame(rafId);

  if (landmarker) {
    try { landmarker.close(); } catch (_) {}
    landmarker = null;
  }

  if (stream) {
    stream.getTracks().forEach(t => t.stop());
    stream = null;
  }

  logOnce("poseStop: stopped");
}

// ✅ 追加：Flutter側の「もう一度試す」ボタン用
async function poseRequestPermission() {
  // まず完全停止してから再トライ
  await poseStop();
  await poseStart();
}

// ---- グローバルへ公開（Flutterの jsutil.callMethod 用） -------------------
window.poseStart = poseStart;
window.poseStop = poseStop;
window.poseRequestPermission = poseRequestPermission;
