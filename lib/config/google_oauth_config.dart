/// OAuth 2.0 **Web client** ID (Google Cloud `client_type: 3` in
/// `android/app/google-services.json`). Required for `google_sign_in` 7.x
/// `initialize(serverClientId: ...)` so Firebase Auth receives a valid ID token
/// on Android/iOS.
///
/// For Flutter web, Firebase popup sign-in uses the same project; this value is
/// also used in `web/index.html` meta `google-signin-client_id`.
const String kGoogleWebServerClientId =
    '1063163612294-8abrnbldcd6jnijs9gino78uqq3ov52t.apps.googleusercontent.com';

