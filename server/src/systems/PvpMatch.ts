import { WebSocket } from 'ws';
import { AuthedSocket, send } from '../ws/PvpGateway';
import { MmrService } from '../services/MmrService';
import { ServerBattleExecutor, RoundExecutionInput, RoundExecutionResult, PetState, PlayerSelection } from './ServerBattleExecutor';

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
  private pendingPetStates: Map<string, PetState[]> = new Map();
  private clientResults: Map<string, string> = new Map();
  private roundTimer: NodeJS.Timeout | null = null;
  private disconnectTimers: Map<string, NodeJS.Timeout> = new Map();
  private executor = new ServerBattleExecutor();
  private petStates: Map<string, PetState[]> = new Map(); // Track state per player

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

    // Initialize pet states from teams
    this.petStates.set(this.players[0].userId, this._initializePetsFromTeam(this.players[0].team));
    this.petStates.set(this.players[1].userId, this._initializePetsFromTeam(this.players[1].team));

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

  handleSubmit(userId: string, round: number, selections: Record<string, string[]>, petStates?: PetState[]): void {
    if (this.status !== 'in_round' || round !== this.round) return;
    if (this.pendingSelections.has(userId)) return; // already submitted

    this.pendingSelections.set(userId, selections);
    if (petStates) {
      this.pendingPetStates.set(userId, petStates);
    }

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

  private async _lockRound(): Promise<void> {
    if (this.roundTimer) clearTimeout(this.roundTimer);
    this.roundTimer = null;

    const [a, b] = this.players;
    const selectionsA = this.pendingSelections.get(a.userId) ?? {};
    const selectionsB = this.pendingSelections.get(b.userId) ?? {};

    // Get pet states from clients (fallback to initial state if not provided)
    let statesA = this.pendingPetStates.get(a.userId) ?? this.petStates.get(a.userId);
    let statesB = this.pendingPetStates.get(b.userId) ?? this.petStates.get(b.userId);

    // Initialize states from DNA if first round
    if (!statesA || !statesB) {
      console.error('[PvP] Missing pet states for round execution');
      this._forfeit(a.userId);
      return;
    }

    try {
      // Execute round server-side with full selections
      const input: RoundExecutionInput = {
        seed: this.seed,
        roundNumber: this.round,
        playerATeam: statesA,
        playerBTeam: statesB,
        playerASelections: selectionsA,
        playerBSelections: selectionsB,
      };

      console.log(`[PvP] Executing round ${this.round} for match ${this.matchId}`);
      const result = await this.executor.executeRound(input);

      if (!result.success || !result.playerATeamAfter || !result.playerBTeamAfter) {
        console.error('[PvP] Round execution failed:', result.error);
        this._forfeit(a.userId);
        return;
      }

      // Update pet states for next round
      const updatedStatesA = result.playerATeamAfter!;
      const updatedStatesB = result.playerBTeamAfter!;

      this.petStates.set(a.userId, updatedStatesA);
      this.petStates.set(b.userId, updatedStatesB);

      // Create pet states map for both clients (same data)
      const petStatesMap: Record<string, any> = {};
      updatedStatesA.forEach(pet => {
        petStatesMap[pet.uid] = {
          hp: pet.hp,
          shield: pet.shield,
          isFainted: pet.isFainted,
        };
      });
      updatedStatesB.forEach(pet => {
        petStatesMap[pet.uid] = {
          hp: pet.hp,
          shield: pet.shield,
          isFainted: pet.isFainted,
        };
      });

      // Broadcast IDENTICAL round result to both clients
      const nextDeadline = Date.now() + ROUND_TIMEOUT_MS;
      const roundResult = {
        type: 'round:result',
        matchId: this.matchId,
        round: this.round,
        turnOrder: result.turnOrder || [],
        petStates: petStatesMap,
        battleComplete: result.battleComplete ?? false,
        nextDeadlineMs: nextDeadline,
      };

      console.log(`[PvP] Broadcasting round ${this.round} result to both players`);
      send(a.socket, roundResult);
      send(b.socket, roundResult);

      this.pendingSelections.clear();
      this.pendingPetStates.clear();

      // Check if battle is complete
      if (result.battleComplete && result.winnerTeam) {
        console.log(`[PvP] Battle complete! Winner: ${result.winnerTeam}`);
        // Map winner team to player UID
        const winnerUid = result.winnerTeam === 'A' ? a.userId : 
                          result.winnerTeam === 'B' ? b.userId : null;
        
        this.status = 'ended';
        
        // Send final result to both players
        const matchEndMsg = {
          type: 'match:end',
          matchId: this.matchId,
          winnerUid: winnerUid ?? null,
          dispute: false,
          mmrDelta: 0,
        };
        
        send(a.socket, matchEndMsg);
        send(b.socket, matchEndMsg);
      } else {
        // Continue with next round
        this.round++;
        this._startRoundTimer();
      }
    } catch (error) {
      console.error('[PvP] Failed to execute round:', error);
      this._forfeit(a.userId);
    }
  }

  private _initializePetsFromTeam(team: PetDna[]): PetState[] {
    return team.map((petDna, index) => {
      // Placeholder: derive stats from DNA (same logic as client)
      // For now, use default stats; real implementation would decode DNA
      return {
        uid: petDna.uid,
        name: `Likha #${petDna.uid.slice(0, 6).toUpperCase()}`,
        hp: 150,
        maxHp: 150,
        spd: 30,
        skl: 20,
        mor: 20,
        dex: 0,
        def: 0,
        shield: 0,           // Initialize shield to 0
        isFainted: false,    // Initialize not fainted
        index: index,
        statusEffects: [],
      };
    });
  }

  private _getPlayerSelection(selections: Record<string, string[]>, teamStates: PetState[]): PlayerSelection {
    // For now, assume selections map petId to [traitName, targetIndex, ...]
    // Real implementation would parse trait names and target indices
    const firstPetId = Object.keys(selections)[0];
    const firstSelection = selections[firstPetId]?.[0];

    if (!firstSelection || !firstPetId) {
      return { traitName: '', targetIndex: 0 };
    }

    // Parse "traitName:targetIndex" format or similar
    const [traitName, targetIndexStr] = firstSelection.split(':');
    const targetIndex = parseInt(targetIndexStr || '0', 10);

    return { traitName: traitName || '', targetIndex };
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
