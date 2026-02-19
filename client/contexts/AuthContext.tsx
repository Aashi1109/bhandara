import { createContext, useContext, useEffect, useState } from "react";

import AsyncStorage from "@react-native-async-storage/async-storage";
import type { IBaseUser, IMedia } from "@/definitions/types";
import { getUserSession, logout as logoutApi } from "@/common/api/auth.action";
import { jnstringify } from "@/utils";

interface AuthContextType {
  user: IBaseUser | undefined;
  session: { id: string } | undefined;
  isLoading: boolean;
  setAuthState: (user: IBaseUser, session: { id: string }) => Promise<void>;
  logout: () => Promise<void>;
  updateUser: (payload: Partial<IBaseUser>) => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: undefined,
  session: undefined,
  isLoading: true,
  setAuthState: async () => {},
  logout: async () => {},
  updateUser: async () => {}
});

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<IBaseUser | undefined>();
  const [session, setSession] = useState<{ id: string } | undefined>();
  const [isLoading, setIsLoading] = useState(true);

  const setAuthState = async (user: IBaseUser, session: { id: string }) => {
    const _user = { ...user };
    if (_user.media && _user.media.publicUrl) {
      if (!_user.profilePic) {
        _user.profilePic = {};
      }
      _user.profilePic.url = (_user.media as IMedia).publicUrl;
    }

    setUser(_user);
    setSession(session);
    await AsyncStorage.setItem("sessionId", session.id);
  };

  const logout = async () => {
    await logoutApi();
    setUser(undefined);
    setSession(undefined);
    await AsyncStorage.removeItem("sessionId");
  };

  const checkUserSession = async () => {
    try {
      setIsLoading(true);
      const res = await getUserSession();
      const { user, session } = res.data;
      if (user && session) {
        await setAuthState(user, session);
      }
    } catch (error) {
      console.log("error", error);
      console.error("Failed to check user session:", jnstringify(error));
    } finally {
      setIsLoading(false);
    }
  };

  const updateUser = async (payload: Partial<IBaseUser>) => {
    const { media, ...rest } = payload;

    const _user = { ...user };

    if (media && media.publicUrl) {
      if (!_user.profilePic) {
        _user.profilePic = { url: "" };
      }
      _user.profilePic.url = media.publicUrl;
      _user.media = media;
      delete rest.profilePic;
    }
    setUser({ ..._user, ...rest } as IBaseUser);
  };

  useEffect(() => {
    checkUserSession();
  }, []);

  return (
    <AuthContext.Provider value={{ user, session, setAuthState, logout, isLoading, updateUser }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};
