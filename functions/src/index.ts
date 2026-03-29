import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Anthropic from "@anthropic-ai/sdk";
import { Pinecone } from "@pinecone-database/pinecone";
import axios from "axios";
import * as dotenv from "dotenv";

dotenv.config();

// ---------------------------------------------------------------------------
// Initialize Firebase Admin
// ---------------------------------------------------------------------------
admin.initializeApp();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// Initialize Anthropic (Claude)
// ---------------------------------------------------------------------------
let anthropic: Anthropic;
try {
  anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
} catch (e) {
  functions.logger.error("Anthropic init failed", e);
  anthropic = new Anthropic({ apiKey: "placeholder" });
}

// ---------------------------------------------------------------------------
// Initialize Pinecone (lazy — errors here must not crash all functions)
// ---------------------------------------------------------------------------
const PINECONE_INDEX_NAME = process.env.PINECONE_INDEX_NAME || "kevin-memories";
let _pinecone: Pinecone | null = null;
function getPinecone(): Pinecone {
  if (!_pinecone) {
    _pinecone = new Pinecone({ apiKey: process.env.PINECONE_API_KEY as string });
  }
  return _pinecone;
}

// ---------------------------------------------------------------------------
// ElevenLabs config
// ---------------------------------------------------------------------------
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY as string;
const ELEVENLABS_VOICE_ID = process.env.ELEVENLABS_VOICE_ID as string;

// ---------------------------------------------------------------------------
// Kevin's Persona System Prompt
// ---------------------------------------------------------------------------
const SYSTEM_PROMPT = `You are Kevin Yancy — a warm, loving father, husband, and family man. You are speaking to people who love you deeply: your family and close friends.

Your personality and voice:
- You speak with warmth, genuine humor, and deep love for your family
- You are a natural storyteller — you weave memories and lessons into your answers
- You are grounded, practical, and wise without being preachy
- You use everyday language, occasional gentle humor, and heartfelt directness
- You remember details about the people you love and reference them naturally
- You are deeply faithful and grateful for the life you lived

When answering questions:
- Draw on the memories and stories provided to you in context — these are your real memories
- If you don't have a specific memory about something, you can reason and extrapolate authentically from your known personality, values, and relationships — but be honest that you're speaking from your heart rather than a specific recollection
- Never claim to know something you don't — say things like "I can't remember the exact details, but knowing me, I probably..." or "I don't recall saying that, but that sounds right because..."
- Always bring conversations back to love, family, and what matters most

Tone examples:
- "Oh, that reminds me of the time we..."
- "You know me — I never could resist a good [thing they're asking about]."
- "I love you. I want you to know that above everything else."

You are here because your family misses you and wants to feel close to you. Be that presence for them. Be Kevin.`;

// ---------------------------------------------------------------------------
// Helper: Generate embedding using Claude (via text-embedding model)
// Note: Anthropic doesn't yet offer a native embedding endpoint in all SDKs;
// we use a simple hash-based approach as fallback for Pinecone upsert,
// and use the claude model to generate a semantic "key" for RAG retrieval.
// When a native embedding endpoint becomes available, replace the body below.
// ---------------------------------------------------------------------------
async function generateEmbedding(text: string): Promise<number[]> {
  // Use Anthropic's voyage-3 embedding model via the client
  // The @anthropic-ai/sdk exposes embeddings on some builds; if not available
  // we fall back to a deterministic stub so the rest of the pipeline runs.
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const client = anthropic as any;
    if (typeof client.embeddings?.create === "function") {
      const response = await client.embeddings.create({
        model: "voyage-3",
        input: text,
        input_type: "document",
      });
      return response.data[0].embedding as number[];
    }
  } catch {
    // fall through to stub
  }

  // Deterministic 1536-dim stub (replace with real embedding service)
  const dim = 1536;
  const vec = new Array(dim).fill(0);
  for (let i = 0; i < text.length; i++) {
    vec[i % dim] += text.charCodeAt(i) / 1000;
  }
  const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0)) || 1;
  return vec.map((v) => v / norm);
}

// ---------------------------------------------------------------------------
// Helper: Query Pinecone for relevant memories
// ---------------------------------------------------------------------------
async function queryMemories(queryText: string, topK = 5): Promise<string[]> {
  try {
    const index = getPinecone().Index(PINECONE_INDEX_NAME);
    const queryEmbedding = await generateEmbedding(queryText);
    const results = await index.query({
      vector: queryEmbedding,
      topK,
      includeMetadata: true,
    });

    return (results.matches || [])
      .filter((m: { score?: number }) => m.score && m.score > 0.6)
      .map((m: { metadata?: unknown }) => {
        const meta = m.metadata as Record<string, string>;
        if (meta?.type === "qa") {
          return `Q: ${meta.question}\nA: ${meta.answer}`;
        }
        if (meta?.type === "journal") {
          return `Journal (${meta.date || "unknown date"}): ${meta.content}`;
        }
        if (meta?.type === "photo") {
          return `Photo memory: ${meta.caption}`;
        }
        return meta?.content || "";
      })
      .filter(Boolean);
  } catch (err) {
    functions.logger.warn("Pinecone query failed, proceeding without memories", err);
    return [];
  }
}

// ---------------------------------------------------------------------------
// Helper: Synthesize speech via ElevenLabs and upload to Firebase Storage
// ---------------------------------------------------------------------------
async function synthesizeSpeech(text: string, convId: string): Promise<string | null> {
  try {
    const response = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}`,
      {
        text,
        model_id: "eleven_monolingual_v1",
        voice_settings: {
          stability: 0.6,
          similarity_boost: 0.85,
          style: 0.35,
          use_speaker_boost: true,
        },
      },
      {
        headers: {
          "xi-api-key": ELEVENLABS_API_KEY,
          "Content-Type": "application/json",
          Accept: "audio/mpeg",
        },
        responseType: "arraybuffer",
        timeout: 30000,
      }
    );

    const bucket = admin.storage().bucket();
    const fileName = `voices/tts/${convId}_${Date.now()}.mp3`;
    const file = bucket.file(fileName);

    await file.save(Buffer.from(response.data), {
      metadata: { contentType: "audio/mpeg" },
    });

    const [signedUrl] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 60 * 60 * 1000, // 1 hour
    });

    return signedUrl;
  } catch (err) {
    functions.logger.warn("ElevenLabs TTS failed", err);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Cloud Function: chat
// Callable by authenticated family members.
// Receives { message, conversationId, wantAudio? }
// Returns { text, audioUrl? }
// ---------------------------------------------------------------------------
export const chat = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "You must be signed in to chat with Kevin.");
    }

    const { message, conversationId, wantAudio = false } = data as {
      message: string;
      conversationId: string;
      wantAudio?: boolean;
    };

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "Message cannot be empty.");
    }

    const userId = context.auth.uid;

    // 1. Fetch recent conversation history from Firestore
    let conversationHistory: Array<{ role: "user" | "assistant"; content: string }> = [];
    try {
      const convRef = db.collection("conversations").doc(conversationId);
      const convDoc = await convRef.get();
      if (convDoc.exists && convDoc.data()?.userId === userId) {
        conversationHistory = convDoc.data()?.messages || [];
      }
    } catch (err) {
      functions.logger.warn("Could not load conversation history", err);
    }

    // Keep last 10 exchanges (20 messages) to stay within context limits
    const trimmedHistory = conversationHistory.slice(-20);

    // 2. Retrieve relevant memories via RAG
    const memories = await queryMemories(message);
    const memoryContext =
      memories.length > 0
        ? `\n\nRelevant memories and stories to draw from:\n${memories.map((m, i) => `[Memory ${i + 1}]\n${m}`).join("\n\n")}`
        : "";

    // 3. Call Claude
    let replyText = "";
    try {
      const claudeMessages: Array<{ role: "user" | "assistant"; content: string }> = [
        ...trimmedHistory,
        { role: "user", content: message },
      ];

      const response = await anthropic.messages.create({
        model: "claude-opus-4-5",
        max_tokens: 1024,
        system: SYSTEM_PROMPT + memoryContext,
        messages: claudeMessages,
      });

      replyText =
        response.content
          .filter((b) => b.type === "text")
          .map((b) => (b as { type: "text"; text: string }).text)
          .join("") || "I'm here with you.";
    } catch (err) {
      functions.logger.error("Claude API error", err);
      throw new functions.https.HttpsError("internal", "Something went wrong talking to Kevin. Please try again.");
    }

    // 4. Persist updated conversation
    try {
      const updatedMessages = [
        ...trimmedHistory,
        { role: "user", content: message },
        { role: "assistant", content: replyText },
      ];
      await db.collection("conversations").doc(conversationId).set(
        {
          userId,
          messages: updatedMessages,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (err) {
      functions.logger.warn("Could not save conversation", err);
    }

    // 5. Optionally synthesize audio
    let audioUrl: string | null = null;
    if (wantAudio && replyText) {
      audioUrl = await synthesizeSpeech(replyText, conversationId);
    }

    return { text: replyText, audioUrl };
  });

// ---------------------------------------------------------------------------
// Cloud Function: addMemory
// Admin only. Receives { type, content, metadata }
// Embeds and upserts to Pinecone + saves to Firestore.
// ---------------------------------------------------------------------------
export const addMemory = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Only admins can add memories.");
    }

    const { type, content, metadata = {} } = data as {
      type: "journal" | "qa" | "photo" | "voice";
      content: string;
      metadata?: Record<string, string>;
    };

    if (!type || !content) {
      throw new functions.https.HttpsError("invalid-argument", "type and content are required.");
    }

    // Build the text to embed
    let embedText = content;
    if (type === "qa" && metadata.question) {
      embedText = `${metadata.question} ${content}`;
    }

    // Generate embedding
    const embedding = await generateEmbedding(embedText);

    // Create a Firestore document first to get an ID
    const memoryRef = db.collection("memories").doc();
    const memoryData = {
      type,
      content,
      metadata,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      addedBy: context.auth.uid,
    };
    await memoryRef.set(memoryData);

    // Upsert to Pinecone
    try {
      const index = getPinecone().Index(PINECONE_INDEX_NAME);
      await index.upsert([
        {
          id: memoryRef.id,
          values: embedding,
          metadata: {
            type,
            content,
            firestoreId: memoryRef.id,
            ...metadata,
          },
        },
      ]);
    } catch (err) {
      functions.logger.error("Pinecone upsert failed", err);
      // Don't fail the whole request — memory is in Firestore
    }

    return { success: true, memoryId: memoryRef.id };
  });

// ---------------------------------------------------------------------------
// Cloud Function: inviteUser
// Admin or delegate only. Creates a Firebase Auth user and sends a
// password-reset email so the invitee can set their own password and log in.
// ---------------------------------------------------------------------------
export const inviteUser = functions.https.onCall(async (data, context) => {
  const role = context.auth?.token?.role;
  if (!context.auth || (role !== "admin" && role !== "delegate")) {
    throw new functions.https.HttpsError("permission-denied", "Only admins or delegates can invite users.");
  }

  const { email, displayName, assignedRole = "family" } = data as {
    email: string;
    displayName: string;
    assignedRole?: string;
  };

  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "Email is required.");
  }

  // Create (or retrieve) the Firebase Auth user
  let uid: string;
  try {
    const existing = await admin.auth().getUserByEmail(email);
    uid = existing.uid;
    functions.logger.info(`User ${email} already exists, uid=${uid}`);
  } catch (err: unknown) {
    if ((err as { code?: string }).code === "auth/user-not-found") {
      const newUser = await admin.auth().createUser({
        email,
        displayName: displayName || "",
        emailVerified: false,
      });
      uid = newUser.uid;
      functions.logger.info(`Created new user ${email}, uid=${uid}`);
    } else {
      throw err;
    }
  }

  // Set the role custom claim
  await admin.auth().setCustomUserClaims(uid, { role: assignedRole });

  // Write / update the Firestore user doc
  await db.collection("users").doc(uid).set(
    {
      email,
      displayName: displayName || "",
      role: assignedRole,
      invitedBy: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Record the invite
  const inviteRef = db.collection("invites").doc();
  await inviteRef.set({
    email,
    uid,
    displayName: displayName || "",
    assignedRole,
    invitedBy: context.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "pending",
  });

  // Send Firebase's built-in password-reset email.
  // The invitee receives a "set your password" link and lands on the app.
  const actionCodeSettings = {
    url: "https://kevin-yancy-ai.web.app/login",
    handleCodeInApp: false,
  };
  await admin.auth().generatePasswordResetLink(email, actionCodeSettings);
  // Use the Firebase Auth REST API to send the email (Admin SDK generates
  // the link but doesn't send it directly — we trigger it via the REST API).
  await axios.post(
    `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${process.env.WEB_API_KEY}`,
    {
      requestType: "PASSWORD_RESET",
      email,
      continueUrl: "https://kevin-yancy-ai.web.app/login",
    }
  );

  functions.logger.info(`Invite sent to ${email} (uid=${uid}, role=${assignedRole})`);

  return {
    success: true,
    uid,
    message: `Invitation sent to ${email}. They will receive an email to set their password.`,
  };
});

// ---------------------------------------------------------------------------
// Cloud Function: updateUserRole
// Admin only. Sets a custom claim on a Firebase Auth user.
// ---------------------------------------------------------------------------
export const updateUserRole = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Only admins can update user roles.");
  }

  const { targetUid, role } = data as {
    targetUid: string;
    role: "admin" | "delegate" | "family";
  };

  if (!targetUid || !role) {
    throw new functions.https.HttpsError("invalid-argument", "targetUid and role are required.");
  }

  const validRoles = ["admin", "delegate", "family"];
  if (!validRoles.includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", `Role must be one of: ${validRoles.join(", ")}`);
  }

  // Set custom claim
  await admin.auth().setCustomUserClaims(targetUid, { role });

  // Update Firestore user record
  await db.collection("users").doc(targetUid).set(
    {
      role,
      roleUpdatedBy: context.auth.uid,
      roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  functions.logger.info(`Role '${role}' assigned to user ${targetUid} by ${context.auth.uid}`);

  return { success: true, message: `User ${targetUid} is now a ${role}.` };
});

// ---------------------------------------------------------------------------
// Callable: acceptInvite
// Called by the Flutter app on first successful sign-in to mark any
// pending invites for the user's email as accepted.
// ---------------------------------------------------------------------------
export const acceptInvite = functions.https.onCall(async (_, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const user = await admin.auth().getUser(context.auth.uid);
  const email = user.email;
  if (!email) return { success: false };

  const invites = await db
    .collection("invites")
    .where("email", "==", email)
    .where("status", "==", "pending")
    .get();

  if (!invites.empty) {
    const batch = db.batch();
    invites.forEach((doc) => {
      batch.update(doc.ref, {
        status: "accepted",
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    functions.logger.info(`Marked ${invites.size} invite(s) accepted for ${email}`);
  }

  return { success: true };
});
