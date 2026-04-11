import 'package:sumquiz/models/user_model.dart';

/// Pro (including active paid or trial subscription) may run YouTube import flows.
bool userMayImportFromYouTube(UserModel? user) => user?.isPro == true;

const String kYoutubeProRequiredMessage =
    'YouTube import is a Pro feature. Upgrade to unlock video-to-study import.';