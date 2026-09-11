class AnalyticsConsentState {
  const AnalyticsConsentState(
      {this.accountId,
      this.granted = false,
      this.saving = false,
      this.saveFailed = false});
  final String? accountId;
  final bool granted;
  final bool saving;
  final bool saveFailed;
}
