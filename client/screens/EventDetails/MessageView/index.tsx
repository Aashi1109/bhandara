import { getChildMessagesForThread, getMessageById, getMessagesForThread } from "@/common/api/messages.action";
import { BackButtonHeader } from "@/components/ui/common-components";
import { SpinningLoader } from "@/components/ui/Loaders";
import { PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import { useAuth } from "@/contexts/AuthContext";
import { useSocket } from "@/contexts/Socket";
import { IBaseThread, IBaseUser, IEvent, IMessage, IPaginationResponse } from "@/definitions/types";
import { useDataLoader } from "@/hooks";
import useSocketListener from "@/hooks/useSocketListener";
import { memo, useCallback, useEffect, useRef, useState } from "react";
import { useDebounce, View, YStack, YStackProps } from "tamagui";
import MessageCard from "./MessageCard";
import { FlatList } from "react-native";
import { useToastController } from "@tamagui/toast";
import { getThreadById } from "@/common/api/threads.action";

enum ViewTypes {
  Thread = "thread",
  ChildMessages = "child",
  Message = "message",
  New = 0
}

type BaseCommonProps = {
  threadId?: string;
  parentId?: string;
  messageId?: string;
  eventId?: string;
};

interface AddMessageProp extends IMessage {
  thread: IBaseThread;
  user: IBaseUser;
  event?: IEvent;
}

export { BaseCommonProps as IMessageViewBaseProps, AddMessageProp as IMessageViewAddMessageProp };

interface IProps extends BaseCommonProps {
  onBack: () => void;
  style: YStackProps["style"];
  handleClick: (data: BaseCommonProps) => void;
}

const MessageView = memo(({ threadId, parentId, messageId, onBack, handleClick, style, eventId }: IProps) => {
  const toastController = useToastController();
  const [isFetchingMore, setIsFetchingMore] = useState(false);
  const [threadData, setThreadData] = useState<IBaseThread | null>(null);

  const paginationRef = useRef<IPaginationResponse>({ limit: 30, next: null, page: 1 });
  const [currentView, setCurrentView] = useState(() => {
    return determineViewType({ threadId, parentId, messageId });
  });

  const headers = {
    [ViewTypes.Thread]: "Thread",
    [ViewTypes.Message]: "Message",
    [ViewTypes.ChildMessages]: "Messages",
    [ViewTypes.New]: "New Thread"
  };

  const methodExecutors = {
    [ViewTypes.Thread]: () => getMessagesForThread({ threadId: threadId || "", pagination: paginationRef.current }),
    [ViewTypes.Message]: () => getMessageById({ messageId: messageId || "", threadId: threadId || "" }),
    [ViewTypes.ChildMessages]: () =>
      getChildMessagesForThread({
        threadId: threadId || "",
        parentId: parentId || "",
        pagination: paginationRef.current
      }),
    [ViewTypes.New]: () => {}
  };

  function determineViewType({ threadId, parentId, messageId }: BaseCommonProps) {
    if (parentId && threadId) return ViewTypes.ChildMessages;
    if (threadId && messageId) return ViewTypes.Message;
    if (threadId) return ViewTypes.Thread;
    return ViewTypes.New;
  }

  const getFormattedData = (data: any) => {
    const _data = data?.data;
    if (currentView === ViewTypes.ChildMessages) {
      paginationRef.current = _data?.pagination;
      return _data?.items || [];
    }
    if (currentView == ViewTypes.Message) {
      return _data;
    }
    if (currentView === ViewTypes.Thread) {
      paginationRef.current = data?.pagination;
      return _data?.items || [];
    }
  };

  async function methodExecutor(currentView: ViewTypes) {
    try {
      const data = await methodExecutors[currentView]();
      return getFormattedData(data);
    } catch (error: any) {
      toastController.show(error?.message || "Something went wrong");
    }
  }

  const { data, loading, setData } = useDataLoader({ promiseFunction: () => methodExecutor(currentView) });
  const socket = useSocket();

  // Fetch thread data when threadId is available
  useEffect(() => {
    if (threadId) {
      getThreadById({ id: threadId })
        .then((response) => {
          setThreadData(response.data);
        })
        .catch((error) => {
          console.error("Error fetching thread:", error);
        });
    }
  }, [threadId]);

  useEffect(() => {
    socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_CREATED, ({ data, error }: { data: AddMessageProp; error: any }) => {
      if (error) return;
      if (data.threadId === threadId) {
        const { thread, ...rest } = data;
        setData((prev: IMessage[]) => [rest, ...prev]);
      }
    });
    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_CREATED, ({ data, error }: { data: IBaseThread; error: any }) => {
      console.log({ data, error });
      if (error) return;

      if (data.eventId === eventId) {
        const messages = data.messages;
        setData((prev: IMessage[]) => [...(messages || []), ...(prev || [])]);
        setCurrentView(ViewTypes.Thread);
      }
    });
  }, [socket]);

  const lastFetchedNext = useRef<string | null>(null);

  const handleEndReached = async () => {
    if ([ViewTypes.Message, ViewTypes.New].includes(currentView)) return;
    const currentPagination = paginationRef.current;

    const shouldPaginate =
      !isFetchingMore &&
      currentPagination?.next !== lastFetchedNext.current &&
      (currentPagination?.next || currentPagination?.page);

    if (shouldPaginate) {
      try {
        setIsFetchingMore(true);
        lastFetchedNext.current = currentPagination?.next ?? `page-${currentPagination.page + 1}`;

        paginationRef.current = {
          ...currentPagination,
          page: currentPagination?.page ? currentPagination.page + 1 : 1,
          next: currentPagination?.next
        };

        const res = await methodExecutors[currentView]();
        const newItems = res?.data?.items || [];
        const newPagination = res?.data?.pagination;

        if (newItems.length) {
          setData((prev: any) => [...prev, ...newItems]);
          paginationRef.current = newPagination;
        }
      } catch (err: any) {
        toastController.show(err?.message || "Failed to load more messages");
      } finally {
        setIsFetchingMore(false);
      }
    }
  };

  const debouncedHandleEndReached = useCallback(useDebounce(handleEndReached, 300), []);

  return (
    <YStack
      gap={"$4"}
      width={"100%"}
      flex={1}
      style={style}
    >
      <BackButtonHeader
        title={headers[currentView]}
        arrowCb={onBack}
      />
      {loading ? (
        <View
          items={"center"}
          justify={"center"}
          height={"100%"}
          width={"100%"}
        >
          <SpinningLoader />
        </View>
      ) : (
        data && (
          <FlatList
            data={data}
            keyExtractor={(item) => item.id}
            renderItem={({ item, index }) => (
              <MessageCard
                isFirst={index === 0}
                thread={{ id: threadId || "", ...threadData }}
                message={item}
                handleClick={handleClick}
              />
            )}
            onEndReachedThreshold={0.15}
            onEndReached={debouncedHandleEndReached}
            ListFooterComponent={isFetchingMore ? <SpinningLoader /> : null}
            initialNumToRender={10}
          />
        )
      )}
    </YStack>
  );
});

export default MessageView;
