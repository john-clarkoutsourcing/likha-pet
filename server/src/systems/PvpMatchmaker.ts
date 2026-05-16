import { v4 as uuidv4 } from 'uuid';
import { AuthedSocket, send } from '../ws/PvpGateway';
import { PvpMatch, PetDna } from './PvpMatch';
import { MmrService } from '../services/MmrService';
import { FirestoreService } from '../services/FirestoreService';

interface QueueEntry {
  socket: AuthedSocket;
  team: PetDna[];
  mmr: number;
  joinedAt: number;
}

const TICK_INTERVAL_MS = 1000;
const BASE_BRACKET     = 100;
const BRACKET_STEP     = 50;   // widen by 50 per 5 s of wait
const MAX_BRACKET      = 500;
const BRACKET_PERIOD   = 5000; // ms between bracket-widen steps

export class PvpMatchmaker {
  private queue: Map<string, QueueEntry> = new Map();
  private activeMatches: Map<string, PvpMatch> = new Map();
  private mmrService: MmrService;
  private firestoreService: FirestoreService;
  private statusInterval: NodeJS.Timeout;

  constructor(firestoreService: FirestoreService) {
    this.firestoreService = firestoreService;
    this.mmrService = new MmrService(firestoreService);
    this.statusInterval = setInterval(() => this._tick(), TICK_INTERVAL_MS);
  }

  async joinQueue(socket: AuthedSocket, team: PetDna[]): Promise<void> {
    const userId = socket.userId;
    if (this.queue.has(userId)) {
      send(socket, { type: 'error', code: 'ALREADY_QUEUED', message: 'Already in queue.' });
      return;
    }

    const mmr = await this._getMmr(socket);
    this.queue.set(userId, { socket, team, mmr, joinedAt: Date.now() });
    console.log(`[Queue] ${userId} joined (MMR ${mmr}). Queue size: ${this.queue.size}`);

    send(socket, {
      type: 'queue:status',
      position: this.queue.size,
      mmr,
    });
  }

  leaveQueue(userId: string): void {
    this.queue.delete(userId);
    console.log(`[Queue] ${userId} left. Queue size: ${this.queue.size}`);
  }

  handleRoundSubmit(
    userId: string,
    matchId: string,
    round: number,
    selections: Record<string, string[]>,
  ): void {
    const match = this.activeMatches.get(matchId);
    if (!match) return;
    match.handleSubmit(userId, round, selections);
  }

  handleClientResult(userId: string, matchId: string, winnerUid: string): void {
    const match = this.activeMatches.get(matchId);
    if (!match) return;
    match.handleClientResult(userId, winnerUid);
  }

  resumeSocket(socket: AuthedSocket, matchId: string): void {
    const match = this.activeMatches.get(matchId);
    if (!match) {
      send(socket, { type: 'error', code: 'MATCH_NOT_FOUND', message: 'Match not found or ended.' });
      return;
    }
    match.resumeSocket(socket.userId, socket);
  }

  onDisconnect(userId: string): void {
    this.queue.delete(userId);
    // Notify active match (if any) — match handles forfeit timer
    for (const match of this.activeMatches.values()) {
      const isParticipant = match.players.some((p) => p.userId === userId);
      if (isParticipant) {
        match.onDisconnect(userId);
        break;
      }
    }
  }

  private _tick(): void {
    if (this.queue.size < 2) return;

    const entries = Array.from(this.queue.entries()); // [userId, entry][]
    const now = Date.now();

    // Try to pair each entry with the closest-MMR unmatched entry
    const matched = new Set<string>();

    for (let i = 0; i < entries.length; i++) {
      const [idA, entryA] = entries[i];
      if (matched.has(idA)) continue;

      const waitMs  = now - entryA.joinedAt;
      const bracket = Math.min(
        BASE_BRACKET + BRACKET_STEP * Math.floor(waitMs / BRACKET_PERIOD),
        MAX_BRACKET,
      );

      let bestId: string | null = null;
      let bestDiff = Infinity;

      for (let j = i + 1; j < entries.length; j++) {
        const [idB, entryB] = entries[j];
        if (matched.has(idB)) continue;
        const diff = Math.abs(entryA.mmr - entryB.mmr);
        if (diff <= bracket && diff < bestDiff) {
          bestDiff = diff;
          bestId = idB;
        }
      }

      if (bestId) {
        matched.add(idA);
        matched.add(bestId);
        const entryB = this.queue.get(bestId)!;
        this.queue.delete(idA);
        this.queue.delete(bestId);
        this._createMatch(entryA, idA, entryB, bestId);
      }
    }

    // Send periodic status to remaining queue members
    for (const [userId, entry] of this.queue) {
      const pos = Array.from(this.queue.keys()).indexOf(userId) + 1;
      send(entry.socket, { type: 'queue:status', position: pos, mmr: entry.mmr });
    }
  }

  private _createMatch(entryA: QueueEntry, idA: string, entryB: QueueEntry, idB: string): void {
    const matchId = uuidv4();
    const seed    = Math.floor(Math.random() * 0x7FFFFFFF);

    const match = new PvpMatch(
      matchId, seed,
      { userId: idA, displayName: entryA.socket.displayName, team: entryA.team, mmr: entryA.mmr, socket: entryA.socket },
      { userId: idB, displayName: entryB.socket.displayName, team: entryB.team, mmr: entryB.mmr, socket: entryB.socket },
      this.mmrService,
    );

    this.activeMatches.set(matchId, match);
    console.log(`[PvP] Match created: ${matchId} (${idA} vs ${idB})`);
    match.start();
  }

  private async _getMmr(socket: AuthedSocket): Promise<number> {
    try {
      return await this.firestoreService.getUserMmr(socket.userId);
    } catch {
      return 1000;
    }
  }
}
