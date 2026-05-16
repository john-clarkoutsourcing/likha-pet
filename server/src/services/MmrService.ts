import { FirestoreService } from './FirestoreService';

const K = 32;

function expectedScore(ratingA: number, ratingB: number): number {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

export interface MmrResult {
  winnerNewMmr: number;
  loserNewMmr: number;
  winnerDelta: number;
  loserDelta: number;
}

export class MmrService {
  constructor(private firestoreService: FirestoreService) {}

  async recordResult(winnerUid: string, loserUid: string): Promise<MmrResult> {
    const [winnerMmr, loserMmr] = await Promise.all([
      this.firestoreService.getUserMmr(winnerUid),
      this.firestoreService.getUserMmr(loserUid),
    ]);

    const expected = expectedScore(winnerMmr, loserMmr);
    const winnerDelta = Math.round(K * (1 - expected));
    const loserDelta  = Math.round(K * (0 - (1 - expected)));

    const winnerNewMmr = Math.max(0, winnerMmr + winnerDelta);
    const loserNewMmr  = Math.max(0, loserMmr  + loserDelta);

    await Promise.all([
      this.firestoreService.setUserMmr(winnerUid, winnerNewMmr),
      this.firestoreService.setUserMmr(loserUid,  loserNewMmr),
    ]);

    return { winnerNewMmr, loserNewMmr, winnerDelta, loserDelta };
  }
}
