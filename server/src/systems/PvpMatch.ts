import { WebSocket } from 'ws';
import { AuthedSocket, send } from '../ws/PvpGateway';
import { MmrService } from '../services/MmrService';

export interface PetDna {
  uid: string;
  dna: string;
  createdAtMs?: number; // Client-provided pet creation timestamp
}

export interface PlayerInfo {
  userId: string;
  displayName: string;
  team: PetDna[];
  mmr: number;
  socket: AuthedSocket;
}

type MatchStatus = 'in_round' | 'awaiting_results' | 'ended';

const ROUND_TIMEOUT_MS = 60_000;
const RECONNECT_GRACE_MS = 30_000;

export class PvpMatch {
  readonly matchId: string;
  readonly seed: number;
  readonly players: [PlayerInfo, PlayerInfo];

  private round = 0;
  private status: MatchStatus = 'in_round';
  private pendingSelections: Map<string, Record<string, string[]>> = new Map();
  private clientResults: Map<string, string> = new Map();
  private roundTimer: NodeJS.Timeout | null = null;
  private disconnectTimers: Map<string, NodeJS.Timeout> = new Map();

  constructor(
    matchId: string,
    seed: number,
    playerA: PlayerInfo,
    playerB: PlayerInfo,
    private mmrService: MmrService,
  ) {
    this.matchId = matchId;
    this.seed    = seed;
    this.players = [playerA, playerB];
  }

  start(): void {
    this.round = 1;
    const deadline = Date.now() + ROUND_TIMEOUT_MS;

    for (const p of this.players) {
      send(p.socket, {
        type: 'match:found',
        matchId: this.matchId,
        seed: this.seed,
        you: { userId: p.userId, displayName: p.displayName, team: p.team, mmr: p.mmr },
        opponent: this._opponentOf(p.userId),
        firstRoundDeadlineMs: deadline,
      });
    }

    this._startRoundTimer();
  }

  handleSubmit(userId: string, round: number, selections: Record<string, string[]>): void {
    if (this.status !== 'in_round' || round !== this.round) return;
    if (this.pendingSelections.has(userId)) return; // already submitted

    this.pendingSelections.set(userId, selections);

    if (this.pendingSelections.size === 2) {
      this._lockRound();
    }
  }

  handleClientResult(userId: string, winnerUid: string): void {
    if (this.status !== 'awaiting_results') return;
    this.clientResults.set(userId, winnerUid);

    if (this.clientResults.size === 2) {
      this._resolveMatch();
    }
  }

  resumeSocket(userId: string, socket: AuthedSocket): void {
    const player = this.players.find((p) => p.userId === userId);
    if (!player) return;

    // Cancel any pending forfeit timer
    const timer = this.disconnectTimers.get(userId);
    if (timer) {
      clearTimeout(timer);
      this.disconnectTimers.delete(userId);
    }

    player.socket = socket;
    send(socket, {
      type: 'match:resume',
      matchId: this.matchId,
      round: this.round,
      status: this.status,
    });
  }

  onDisconnect(userId: string): void {
    if (this.status === 'ended') return;

    const timer = setTimeout(() => {
      this._forfeit(userId);
    }, RECONNECT_GRACE_MS);
    this.disconnectTimers.set(userId, timer);

    const opponent = this.players.find((p) => p.userId !== userId);
    if (opponent) {
      send(opponent.socket, {
        type: 'opponent:disconnected',
        gracePeriodMs: RECONNECT_GRACE_MS,
      });
    }
  }

  private _lockRound(): void {
    if (this.roundTimer) clearTimeout(this.roundTimer);
    this.roundTimer = null;

    const [a, b] = this.players;
    const selectionsA = this.pendingSelections.get(a.userId) ?? {};
    const selectionsB = this.pendingSelections.get(b.userId) ?? {};

    const nextDeadline = Date.now() + ROUND_TIMEOUT_MS;
    const locked = {
      type: 'round:locked',
      matchId: this.matchId,
      round: this.round,
      selections: {
        [a.userId]: selectionsA,
        [b.userId]: selectionsB,
      },
      nextDeadlineMs: nextDeadline,
    };

    send(a.socket, locked);
    send(b.socket, locked);

    this.pendingSelections.clear();
    this.round++;

    // After max rounds both clients send client:result simultaneously.
    // We don't know max rounds here — wait for both to call handleClientResult.
    this.status = 'awaiting_results';
    // Note: if only some rounds have been played, clients call back into
    // handleSubmit for subsequent rounds; status returns to 'in_round' below.
    // Actually clients handle this: after round:locked they simulate, and if
    // battle isn't over they'll submit the next round.
    this.status = 'in_round';
    this._startRoundTimer();
  }

  private _startRoundTimer(): void {
    if (this.roundTimer) clearTimeout(this.roundTimer);
    this.roundTimer = setTimeout(() => {
      // Auto-lock with empty selections for any missing player
      for (const p of this.players) {
        if (!this.pendingSelections.has(p.userId)) {
          this.pendingSelections.set(p.userId, {});
        }
      }
      this._lockRound();
    }, ROUND_TIMEOUT_MS);
  }

  private async _resolveMatch(): Promise<void> {
    this.status = 'ended';
    if (this.roundTimer) clearTimeout(this.roundTimer);

    const [uA, uB] = [this.players[0].userId, this.players[1].userId];
    const resultA  = this.clientResults.get(uA);
    const resultB  = this.clientResults.get(uB);

    let winnerUid: string | null = null;
    let loserUid: string | null  = null;
    let dispute = false;

    if (resultA === resultB && resultA) {
      winnerUid = resultA;
      loserUid  = winnerUid === uA ? uB : uA;
    } else {
      dispute = true;
      console.warn(`[PvP] Dispute in match ${this.matchId}: A says ${resultA}, B says ${resultB}`);
    }

    let mmrDelta = 0;
    if (winnerUid && loserUid) {
      try {
        const result = await this.mmrService.recordResult(winnerUid, loserUid);
        mmrDelta = result.winnerDelta;
      } catch (e) {
        console.error('[PvP] MMR update failed:', e);
      }
    }

    for (const p of this.players) {
      const isWinner = p.userId === winnerUid;
      send(p.socket, {
        type: 'match:end',
        matchId: this.matchId,
        winnerUid: winnerUid ?? null,
        dispute,
        mmrDelta: isWinner ? mmrDelta : -mmrDelta,
      });
    }
  }

  private _forfeit(userId: string): void {
    const opponent = this.players.find((p) => p.userId !== userId);
    if (!opponent || this.status === 'ended') return;

    this.clientResults.set(userId, opponent.userId);
    this.clientResults.set(opponent.userId, opponent.userId);
    this._resolveMatch();
  }

  private _opponentOf(userId: string) {
    const opp = this.players.find((p) => p.userId !== userId)!;
    return { userId: opp.userId, displayName: opp.displayName, team: opp.team, mmr: opp.mmr };
  }
}
