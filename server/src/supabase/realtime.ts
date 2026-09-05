import { Event } from '@/features/events/model';
import { EAccessLevel } from '@/common/definitions/enums';
import EventService from '@/features/events/service';
import { emitSocketEvent } from '@/socket/emitter';
import { PLATFORM_SOCKET_EVENTS } from '@/common/constants';
import { logger, supabase, type IMedia } from '@/common';
import { MEDIA_TABLE_NAME } from '@/features/media/constants';

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
            where: { id: eventId, visibility: EAccessLevel.Public },
            raw: true,
          });
          // Public only: this is an unscoped broadcast to every connected
          // socket, so a private event's payload would land on strangers.
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
