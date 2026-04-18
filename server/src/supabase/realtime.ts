import { Event } from '@/src/features/events/model';
import EventService from '@/src/features/events/service';
import { emitSocketEvent } from '@/src/socket/emitter';
import { PLATFORM_SOCKET_EVENTS } from '@/src/common/constants';
import { logger, supabase, type IMedia } from '@/src/common';
import { MEDIA_TABLE_NAME } from '@/src/features/media/constants';

const eventService = new EventService();
export function initializeMediaRealtime() {
  const channel = supabase
    .channel('table-db-changes')
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: MEDIA_TABLE_NAME,
      } as any,
      async (payload: { new: IMedia; [key: string]: any }) => {
        const eventId = payload.new.metadata?.eventId;
        if (!eventId) return;
        try {
          const events = await Event.findAll({
            where: { id: eventId },
            raw: true,
          });
          for (const e of events) {
            const ev = await eventService.getEventData((e as any).id);
            emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_UPDATE, { data: ev });
          }
        } catch (err) {
          logger.error('Realtime handler error', err);
        }
      },
    )
    .subscribe();
  return channel;
}
