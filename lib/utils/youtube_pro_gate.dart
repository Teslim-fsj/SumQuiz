import 'package:sumquiz/models/user_model.dart';

/// Check if user has active CUs or is Pro to run import/upload flows.
bool userMayImportFromYouTube(UserModel? user) =>
    user == null ||
    user.isPro ||
    user.computeUnits > 0 ||
    user.role == UserRole.creator;

const String kYoutubeProRequiredMessage =
    'Neural capacity depleted. Upgrade to unlock more neural bandwidth!';

bool userMayImportFromPdf(UserModel? user) =>
    user == null ||
    user.isPro ||
    user.computeUnits > 0 ||
    user.role == UserRole.creator;

const String kPdfProRequiredMessage =
    'Neural capacity depleted. Upgrade to unlock more neural bandwidth!';

bool userMayImportFromWeb(UserModel? user) =>
    user == null ||
    user.isPro ||
    user.computeUnits > 0 ||
    user.role == UserRole.creator;

const String kWebProRequiredMessage =
    'Neural capacity depleted. Upgrade to unlock more neural bandwidth!';
