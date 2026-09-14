/// A telemetry mean must be weighted by that metric's valid samples, never
/// by the number of buckets or the unfiltered raw row count.
double? weightedDailyMean(Iterable<({double? mean, int validCount})> samples) {
  var sum = 0.0;
  var count = 0;
  for (final sample in samples) {
    final value = sample.mean;
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        sample.validCount <= 0) {
      continue;
    }
    sum += value * sample.validCount;
    count += sample.validCount;
  }
  return count == 0 ? null : sum / count;
}
