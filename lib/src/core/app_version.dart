/// Product and build identity shared by runtime metadata surfaces.
///
/// Keep these values in sync with the single release source of truth in
/// `pubspec.yaml`. The repository privacy audit fails closed if they drift.
const String appVersionName = '1.1.0';
const int appBuildNumber = 2;
const String appTechnicalVersion = '$appVersionName+$appBuildNumber';
