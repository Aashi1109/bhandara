import { supabase } from "@/connections";
import { RequestContext } from "@/contexts";
import { EAuthProvider } from "@/definitions/enums";
import { IBaseUser } from "@/definitions/types";
import {
  getSafeUser,
  setUserCache,
  setUserSessionCache,
} from "@/features/users/helpers";
import UserService from "@/features/users/service";
import { getAlphaNumericId, getGeoLocationData, getUUIDv7 } from "@/helpers";
import { AuthResponse } from "@supabase/supabase-js";
import { Request } from "express";
import { UAParser } from "ua-parser-js";

class Auth {
  private userService: UserService;
  constructor() {
    this.userService = new UserService();
  }

  performOAuth = async (provider: "github" | "google", redirectTo: string) => {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo,
        skipBrowserRedirect: true,
      },
    });
    if (error) throw error;
  };

  sendMagicLink = async (email: string, redirectTo: string) => {
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: redirectTo,
      },
    });

    if (error) throw error;
  };

  signUpNewUser = async (
    email: string,
    password: string,
    redirectTo: string
  ) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: redirectTo,
      },
    });
    if (error) throw error;
    return data;
  };

  signInWithEmail = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;
    return data;
  };

  sendResetPasswordEmail = async (email: string, redirectTo: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo,
    });
    if (error) throw error;
  };

  updatePassword = async (password: string) => {
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw error;
  };

  signOut = async (scope: "global" | "local" | "others") => {
    if (scope === "global") {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
    } else {
      const { error } = await supabase.auth.signOut({ scope });
      if (error) throw error;
    }
  };

  refreshSession = async (refreshToken: string) => {
    const { data, error } = await supabase.auth.refreshSession({
      refresh_token: refreshToken,
    });
    if (error) throw error;
    return data;
  };

  createPlatformUser = async ({
    sessionData,
    req,
    existingUser,
  }: {
    req: Request;
    sessionData: AuthResponse;
    existingUser?: IBaseUser;
  }) => {
    const { data, error } = sessionData;
    if (error) throw error;

    const { user, session } = data;

    RequestContext.setContextValue("session", {
      accessToken: session?.access_token,
      refreshToken: session?.refresh_token,
    });

    if (!existingUser) {
      const userData = await this.userService.getUserByEmail(user.email);
      existingUser = userData;
    }

    // Extract IP and location info
    const ip =
      (req.headers["x-forwarded-for"] as string)?.split(",")[0] ||
      req.socket.remoteAddress;
    const rawUserAgent = req.headers["user-agent"] as string;

    let geoLocationData = await getGeoLocationData(ip);

    if (!existingUser) {
      // create new user
      let profilePic = null;

      const authProvider = user.app_metadata.provider;

      if (authProvider === EAuthProvider.Google) {
        profilePic = {
          url: user.user_metadata.avatar_url,
          provider: authProvider,
        };
      }

      const newUserData = {
        id: getUUIDv7(),
        __sid: user.id, // supabase user id
        email: user.email,
        name: user.user_metadata.full_name,
        gender: "-", // will be updated later
        address: geoLocationData,
        isVerified: Object.values(EAuthProvider).includes(
          authProvider as EAuthProvider
        ),
        profilePic,
        mediaId: user.user_metadata?.mediaId,
        meta: {
          auth: {
            authProvider: user.app_metadata.provider,
          },
          hasOnboarded: false,
        },
      };

      const newUser = await this.userService.create(newUserData);
      existingUser = (newUser as any)?.[0] ?? newUser;
    }
    existingUser = getSafeUser(existingUser);
    await setUserCache(existingUser.id, existingUser);

    // Extract device metadata
    const parser = new UAParser();
    const deviceInfo = parser.setUA(rawUserAgent).getResult();

    const finalUserAgent = {
      device: {
        model: deviceInfo.device.model,
        vendor: deviceInfo.device.vendor,
      },
      os: {
        name: deviceInfo.os.name,
        version: deviceInfo.os.version,
      },
      browser: {
        name: deviceInfo.browser.name,
        version: deviceInfo.browser.major,
      },
      ua: deviceInfo.ua,
    };

    const sessionDataToSave = {
      accessToken: session?.access_token,
      refreshToken: session?.refresh_token,
      userAgent: finalUserAgent,
      location: geoLocationData,
      expiresAt: new Date(
        new Date(0).setUTCSeconds(session.expires_at)
      ).toISOString(),
      expiresIn: session.expires_in,
      user: { id: existingUser.id },
    };

    const sessionId = getAlphaNumericId();

    await setUserSessionCache({
      userId: existingUser.id,
      sessionId,
      data: sessionDataToSave,
    });

    return { sessionId, user: existingUser };
  };
}

export default Auth;
