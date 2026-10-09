import fs from "node:fs";
import path from "node:path";

// ─────────────────────────────────────────────────────────────
// 🎬 AUSTRAL PROMO ENGINE — Highlight Detector
// ─────────────────────────────────────────────────────────────

const CONFIG = {
  // Qué tan importante es cada evento
  weights: {
    // Acción básica
    throw: 1,

    // Resultado
    score: 8,
    miss: 2,

    // Flujo del juego
    game_start: 0,
    level_loaded: 0,
    level_complete: 18,

    // Eventos especiales futuros
    perfect_hit: 15,
    near_miss: 6,
    combo: 12,
    death: 4,
  },

  // Eventos separados por menos de esto pertenecen
  // al mismo "momento".
  clusterGap: 4,

  // Cuánto video conservar antes/después del momento.
  preRoll: 3,
  postRoll: 2,

  // Evita highlights gigantes.
  maxHighlightDuration: 15,

  // OFFSET:
  // Godot arrancó ~75 segundos antes que la grabación.
  // Por lo tanto:
  //
  // timestamp_video = timestamp_godot - 75
  //
  videoOffset: 75,
};

// ─────────────────────────────────────────────────────────────
// Input
// ─────────────────────────────────────────────────────────────

const input = process.argv[2];

if (!input) {
  console.error(`
❌ Missing events file.

Usage:

  node scripts/find-highlights.mjs ./events.jsonl
`);
  process.exit(1);
}

if (!fs.existsSync(input)) {
  console.error(`❌ File not found: ${input}`);
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────
// Parse JSONL
// ─────────────────────────────────────────────────────────────

const events = fs
  .readFileSync(input, "utf8")
  .split(/\r?\n/)
  .map(line => line.trim())
  .filter(Boolean)
  .map((line, index) => {
    try {
      return JSON.parse(line);
    } catch {
      console.error(`❌ Invalid JSON at line ${index + 1}`);
      process.exit(1);
    }
  })
  .filter(event => typeof event.time === "number")
  .sort((a, b) => a.time - b.time);

console.log(`
╔══════════════════════════════════════════════╗
║        🎬 AUSTRAL PROMO ENGINE              ║
║        Highlight Detector v0.2              ║
╚══════════════════════════════════════════════╝
`);

console.log(`📁 ${path.resolve(input)}`);
console.log(`🎮 ${events.length} gameplay events found`);
console.log(`⏱️  Video timeline offset: -${CONFIG.videoOffset}s\n`);

// ─────────────────────────────────────────────────────────────
// Score
// ─────────────────────────────────────────────────────────────

function eventScore(event) {
  let score = CONFIG.weights[event.event] ?? 0;

  if (event.event === "combo") {
    const combo =
      event.data?.combo ??
      event.data?.value ??
      1;

    score += Math.min(combo * 2, 20);
  }

  if (event.event === "score") {
    const points =
      event.data?.score ??
      event.data?.points ??
      event.data?.value ??
      0;

    // Bonus pequeño por scores altos.
    score += Math.min(points / 100, 10);
  }

  return score;
}

// ─────────────────────────────────────────────────────────────
// Build clusters
// ─────────────────────────────────────────────────────────────

const relevantEvents = events.filter(
  event => eventScore(event) > 0
);

const clusters = [];

for (const event of relevantEvents) {
  const last = clusters.at(-1);

  if (
    !last ||
    event.time - last.lastEventTime > CONFIG.clusterGap
  ) {
    clusters.push({
      events: [event],
      firstEventTime: event.time,
      lastEventTime: event.time,
    });
  } else {
    last.events.push(event);
    last.lastEventTime = event.time;
  }
}

// ─────────────────────────────────────────────────────────────
// Calculate highlight score
// ─────────────────────────────────────────────────────────────

function calculateCluster(cluster) {
  let score = cluster.events.reduce(
    (total, event) => total + eventScore(event),
    0
  );

  const types = cluster.events.map(e => e.event);

  const bonuses = [];

  // ── Interesting sequences ───────────────────────────────

  if (
    types.includes("near_miss") &&
    types.includes("score")
  ) {
    score += 10;
    bonuses.push("near miss → score");
  }

  if (
    types.includes("near_miss") &&
    types.includes("perfect_hit")
  ) {
    score += 15;
    bonuses.push("near miss → PERFECT");
  }

  if (
    types.includes("score") &&
    types.includes("level_complete")
  ) {
    score += 12;
    bonuses.push("score → level complete");
  }

  if (
    types.includes("combo") &&
    types.includes("level_complete")
  ) {
    score += 15;
    bonuses.push("combo → level complete");
  }

  // Muchos eventos juntos suelen significar acción.
  if (cluster.events.length >= 4) {
    score += 5;
    bonuses.push("high activity");
  }

  // Centro ponderado del highlight.
  const totalWeight = cluster.events.reduce(
    (sum, event) => sum + eventScore(event),
    0
  );

  const originalCenter =
    cluster.events.reduce(
      (sum, event) =>
        sum + event.time * eventScore(event),
      0
    ) / totalWeight;

  // Primero calculamos usando el reloj original de Godot.
  let originalStart = Math.max(
    0,
    cluster.firstEventTime - CONFIG.preRoll
  );

  let originalEnd =
    cluster.lastEventTime + CONFIG.postRoll;

  // Limitamos duración máxima.
  if (
    originalEnd - originalStart >
    CONFIG.maxHighlightDuration
  ) {
    originalStart = Math.max(
      0,
      originalCenter -
        CONFIG.maxHighlightDuration / 2
    );

    originalEnd =
      originalStart +
      CONFIG.maxHighlightDuration;
  }

  // ───────────────────────────────────────────────────────
  // Convert Godot timeline → Video timeline
  // ───────────────────────────────────────────────────────

  const start = Math.max(
    0,
    originalStart - CONFIG.videoOffset
  );

  const end = Math.max(
    0,
    originalEnd - CONFIG.videoOffset
  );

  const center = Math.max(
    0,
    originalCenter - CONFIG.videoOffset
  );

  return {
    ...cluster,

    score: Math.round(score),

    start,
    end,
    center,

    originalStart,
    originalEnd,
    originalCenter,

    bonuses,
  };
}

// ─────────────────────────────────────────────────────────────
// ALL highlights
//
// IMPORTANTE:
// Antes teníamos:
//
//   .slice(0, CONFIG.top)
//
// Eso limitaba el resultado a los mejores 5.
// Ahora devolvemos TODOS, ordenados por score.
// ─────────────────────────────────────────────────────────────

const highlights = clusters
  .map(calculateCluster)

  // Si terminó antes de que empezara la grabación,
  // no existe en el video.
  .filter(highlight => highlight.end > 0)

  // Más relevante → menos relevante.
  .sort((a, b) => b.score - a.score);

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

function timestamp(seconds) {
  const min = Math.floor(seconds / 60);

  const sec = (seconds % 60)
    .toFixed(1)
    .padStart(4, "0");

  return `${String(min).padStart(2, "0")}:${sec}`;
}

function bar(score) {
  const size = Math.min(
    20,
    Math.round(score / 3)
  );

  return (
    "█".repeat(size) +
    "░".repeat(20 - size)
  );
}

// ─────────────────────────────────────────────────────────────
// Fancy console
// ─────────────────────────────────────────────────────────────

console.log(
  `🔥 ${highlights.length} PROMO CANDIDATES — MOST → LEAST RELEVANT\n`
);

highlights.forEach((highlight, index) => {
  const medal =
    index === 0
      ? "🥇"
      : index === 1
        ? "🥈"
        : index === 2
          ? "🥉"
          : "  ";

  console.log(
`${medal} #${index + 1}

   ${timestamp(highlight.start)}
       │
       ▼
   ┌─────────────────────────────────────┐
   │ ${bar(highlight.score)} │
   └─────────────────────────────────────┘
       ▲
       │
   ${timestamp(highlight.end)}

   🔥 Score: ${highlight.score}
   🎯 Peak:  ${timestamp(highlight.center)}
   ⏱️  Clip:  ${(highlight.end - highlight.start).toFixed(1)}s`
  );

  console.log("\n   Events:");

  for (const event of highlight.events) {
    const weight = eventScore(event);

    const videoTime = Math.max(
      0,
      event.time - CONFIG.videoOffset
    );

    console.log(
      `     ${timestamp(event.time)} Godot → ${timestamp(videoTime)} video  ${event.event.padEnd(18)} +${weight.toFixed(1)}`
    );
  }

  if (highlight.bonuses.length) {
    console.log(
      `\n   ✨ ${highlight.bonuses.join(" · ")}`
    );
  }

  console.log(
    "\n──────────────────────────────────────────────\n"
  );
});

// ─────────────────────────────────────────────────────────────
// Winner + summary
// ─────────────────────────────────────────────────────────────

if (highlights.length) {
  const winner = highlights[0];

  console.log(`
🏆 BEST MOMENT FOUND

   ${timestamp(winner.start)} → ${timestamp(winner.end)}

   Score: ${winner.score}

   Suggested FFmpeg:

   ffmpeg -ss ${winner.start.toFixed(2)} \\
          -to ${winner.end.toFixed(2)} \\
          -i output.mp4 \\
          -c:v libx264 \\
          -c:a aac \\
          highlight.mp4
`);

  console.log(`
╔══════════════════════════════════════════════╗
║            🎞️ ALL HIGHLIGHT CUTS           ║
╚══════════════════════════════════════════════╝
`);

  highlights.forEach((highlight, index) => {
    console.log(
      `#${String(index + 1).padStart(2, "0")}  ` +
      `score=${String(highlight.score).padStart(3, " ")}  ` +
      `${timestamp(highlight.start)} → ${timestamp(highlight.end)}  ` +
      `(${(highlight.end - highlight.start).toFixed(1)}s)`
    );
  });

  console.log(`
──────────────────────────────────────────────

Total highlights: ${highlights.length}
Timeline correction: -${CONFIG.videoOffset}s

──────────────────────────────────────────────
`);
} else {
  console.log("😴 No interesting moments found.");
}