import PushNotification from 'react-native-push-notification';
import { Platform, PermissionsAndroid } from 'react-native';

export class NotificationManager {
  static async initialize() {
    // Configure push notifications
    PushNotification.configure({
      onNotification: this.handleNotificationReceived,
      requestPermissions: Platform.OS === 'ios',
    });

    // Request permissions
    await this.requestPermissions();

    // Create default channel for Android
    if (Platform.OS === 'android') {
      PushNotification.createChannel(
        {
          channelId: 'default',
          channelName: 'Default Channel',
          channelDescription: 'GluCoPilot notifications',
          soundName: 'default',
          importance: 4,
          vibrate: true,
        },
        (created) => console.log(`createChannel returned '${created}'`)
      );
    }
  }

  static async requestPermissions() {
    if (Platform.OS === 'android') {
      try {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
          {
            title: 'Notification Permission',
            message: 'GluCoPilot needs permission to send you glucose alerts',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          }
        );
        return granted === PermissionsAndroid.RESULTS.GRANTED;
      } catch (err) {
        console.warn('Error requesting notification permissions:', err);
        return false;
      }
    }
    return true; // iOS permissions are requested automatically in configure
  }

  static async scheduleGlucoseAlert(title: string, body: string) {
    PushNotification.localNotification({
      title,
      message: body,
      channelId: 'default',
      playSound: true,
      soundName: 'default',
      priority: 'high',
      importance: 'high',
    });
  }

  private static handleNotificationReceived(notification: any) {
    console.log('Notification received:', notification);
    // Handle notification tap
    if (notification.userInteraction) {
      // User tapped the notification
      console.log('User tapped notification');
    }
  }
}
