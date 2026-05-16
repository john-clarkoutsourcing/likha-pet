import * as http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { URL } from 'url';
import jwt from 'jsonwebtoken';
import { JWTPayload } from '../models/User';
import { PvpMatchmaker } from '../systems/PvpMatchmaker';
import { FirestoreService } from '../services/FirestoreService';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

export interface AuthedSocket extends WebSocket {
  userId: string;
  displayName: string;
}

export function send(socket: WebSocket, msg: object): void {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(msg));
  }
}

export class PvpGateway {
  static attach(server: http.Server, firestoreService: FirestoreService): void {
    const wss = new WebSocketServer({ noServer: true });
    const matchmaker = new PvpMatchmaker(firestoreService);

    server.on('upgrade', (req, socket, head) => {
      // Only handle upgrades to /pvp
      const pathname = req.url ? new URL(req.url, 'http://localhost').pathname : '';
      if (pathname !== '/pvp') {
        socket.destroy();
        return;
      }

      // Verify JWT from query string ?token=...
      const params = new URL(req.url!, 'http://localhost').searchParams;
      const token = params.get('token') || '';
      let payload: JWTPayload;
      try {
        payload = jwt.verify(token, JWT_SECRET) as JWTPayload;
      } catch {
        socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
        socket.destroy();
        return;
      }

      wss.handleUpgrade(req, socket, head, (ws) => {
        const authed = ws as AuthedSocket;
        authed.userId = payload.userId;
        authed.displayName = payload.email;
        wss.emit('connection', authed, req);
      });
    });

    wss.on('connection', (ws: WebSocket) => {
      const socket = ws as AuthedSocket;
      console.log(`[PvP] Connected: ${socket.userId}`);

      // Resume an in-progress match on reconnect
      const resumeMatchId = new URL(
        // req is not in scope here — matchId is forwarded in the first message instead
        'http://dummy',
      ).searchParams.get('resume');
      void resumeMatchId; // handled via message below

      socket.on('message', (raw) => {
        let msg: Record<string, unknown>;
        try {
          msg = JSON.parse(raw.toString());
        } catch {
          send(socket, { type: 'error', code: 'BAD_JSON', message: 'Invalid JSON' });
          return;
        }

        switch (msg.type) {
          case 'queue:join':
            matchmaker.joinQueue(socket, msg.team as Array<{ uid: string; dna: string }>);
            break;
          case 'queue:leave':
            matchmaker.leaveQueue(socket.userId);
            break;
          case 'round:submit':
            matchmaker.handleRoundSubmit(
              socket.userId,
              msg.matchId as string,
              msg.round as number,
              msg.selections as Record<string, string[]>,
            );
            break;
          case 'client:result':
            matchmaker.handleClientResult(
              socket.userId,
              msg.matchId as string,
              msg.winnerUid as string,
            );
            break;
          case 'match:resume':
            matchmaker.resumeSocket(socket, msg.matchId as string);
            break;
          default:
            send(socket, { type: 'error', code: 'UNKNOWN_TYPE', message: `Unknown message type: ${msg.type}` });
        }
      });

      socket.on('close', () => {
        console.log(`[PvP] Disconnected: ${socket.userId}`);
        matchmaker.onDisconnect(socket.userId);
      });
    });

    console.log('✓ PvP WebSocket gateway attached at /pvp');
  }
}
