import 'package:integration_test/integration_test_driver.dart';

// Writes the e2e perf report to build/e2e/e2e_perf.json, also when a check
// fails, so a failing run still leaves its measurements behind.
Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) =>
      writeResponseData(data, testOutputFilename: 'e2e_perf', destinationDirectory: 'build/e2e'),
);
