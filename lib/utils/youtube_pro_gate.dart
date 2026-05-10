import 'package:sumquiz/models/user_model.dart';

/// Pro users and Educators (creators) may run YouTube import flows.
bool userMayImportFromYouTube(UserModel? user) =>
    user?.isPro == true || user?.role == UserRole.creator;

const String kYoutubeProRequiredMessage =
    'YouTube import is a Pro feature. Upgrade to unlock video-to-study import.';

bool userMayImportFromPdf(UserModel? user) =>
    user?.isPro == true || user?.role == UserRole.creator;

const String kPdfProRequiredMessage =
    'PDF import is a Pro feature. Upgrade to unlock document-to-study import.';

bool userMayImportFromWeb(UserModel? user) =>
    user?.isPro == true || user?.role == UserRole.creator;

const String kWebProRequiredMessage =
    'Web import is a Pro feature. Upgrade to unlock webpage-to-study import.';
