import { Platform, Share as RNShare } from 'react-native';
import * as Clipboard from 'expo-clipboard';

/**
 * Share a link using the native share dialog. Falls back to copying the
 * link to the clipboard when the Web Share API is not available.
 */
export async function shareLink(url: string) {
  try {
    if (Platform.OS === 'web') {
      if (navigator.share) {
        await navigator.share({ url });
      } else {
        await Clipboard.setStringAsync(url);
        alert('Link copied to clipboard');
      }
    } else {
      await RNShare.share({ message: url, url });
    }
  } catch (e) {
    console.warn('Share failed', e);
  }
}
