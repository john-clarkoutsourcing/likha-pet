import { spawn } from 'child_process';
import * as path from 'path';

export interface PetState {
  uid: string;
  name: string;
  hp: number;
  maxHp: number;
  spd: number;
  skl: number;
  mor: number;
  dex: number;
  def: number;
  shield: number;     // NEW: Shield value (absorbed damage)
  isFainted: boolean; // NEW: Whether pet is defeated
  index: number;
  statusEffects: StatusEffect[];
}

export interface StatusEffect {
  name: string;
  remainingRounds: number;
  magnitude: number;
}

export interface PlayerSelection {
  traitName: string;
  targetIndex: number;
}

export interface RoundExecutionInput {
  seed: number;
  roundNumber: number;
  playerATeam: PetState[];
  playerBTeam: PetState[];
  playerASelection: PlayerSelection;
  playerBSelection: PlayerSelection;
}

export interface TurnOrderEntry {
  uid: string;
  name: string;
  index: number;
}

export interface RoundExecutionResult {
  success: boolean;
  roundNumber?: number;
  turnOrder?: TurnOrderEntry[];
  petStates?: Record<string, any>;
  battleComplete?: boolean;
  error?: string;
  stackTrace?: string;
}

/**
 * Server-side battle executor.
 * Spawns a Dart CLI process to execute battles deterministically.
 * Guarantees both clients see identical results.
 */
export class ServerBattleExecutor {
  private dartBinaryPath: string;

  constructor() {
    // Path to the battle_engine Dart package
    this.dartBinaryPath = path.join(
      __dirname,
      '../../battle_engine/bin/execute_round.dart'
    );
  }

  /**
   * Execute one round of battle on the server.
   * @param input - Battle state and player selections
   * @returns Round result with turn order and pet states
   */
  async executeRound(input: RoundExecutionInput): Promise<RoundExecutionResult> {
    return new Promise((resolve, reject) => {
      const process = spawn('dart', ['run', this.dartBinaryPath], {
        cwd: path.join(__dirname, '../../'),
        timeout: 30000, // 30 second timeout per round
      });

      let output = '';
      let errorOutput = '';

      process.stdout.on('data', (data) => {
        output += data.toString();
      });

      process.stderr.on('data', (data) => {
        errorOutput += data.toString();
      });

      process.on('error', (err) => {
        reject(new Error(`Failed to spawn Dart process: ${err.message}`));
      });

      process.on('close', (code) => {
        if (code !== 0) {
          reject(
            new Error(
              `Dart process exited with code ${code}. Stderr: ${errorOutput}`
            )
          );
          return;
        }

        try {
          const result: RoundExecutionResult = JSON.parse(output);
          if (result.success) {
            resolve(result);
          } else {
            reject(
              new Error(
                `Battle execution failed: ${result.error || 'Unknown error'}`
              )
            );
          }
        } catch (err) {
          reject(
            new Error(
              `Failed to parse battle result: ${err instanceof Error ? err.message : String(err)}`
            )
          );
        }
      });

      // Send input to the process
      process.stdin.write(JSON.stringify(input));
      process.stdin.end();
    });
  }
}
