import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What Windows says about a printer right now.
enum PrinterReadiness { ready, notFound, offline, stuckQueue, unknown }

/// A print waiting this long or more is stuck, not busy.
const int kStuckJobSeconds = 30;

/// Reads Windows' own printer status. The `printing` package says a printer is
/// available even when it is switched off, so this is what decides whether a
/// ticket may be charged. The name goes in through the environment, never into
/// the script text.
class PrinterStatusReader {
  /// Runs the status script; replaced in tests.
  final Future<String> Function(String printerName) run;
  final Duration limit;

  PrinterStatusReader({Future<String> Function(String)? run, this.limit = const Duration(seconds: 3)})
      : run = run ?? _runPowerShell;

  static const String _script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$n = $env:BSG_PRINTER
$p = Get-CimInstance Win32_Printer | Where-Object { $_.Name -eq $n } | Select-Object -First 1
if (-not $p) { '{"found":false}'; exit }
$jobs = @(Get-CimInstance Win32_PrintJob | Where-Object { $_.Name -like "$n,*" })
$oldest = 0
foreach ($j in $jobs) {
  $age = ((Get-Date) - $j.TimeSubmitted).TotalSeconds
  if ($age -gt $oldest) { $oldest = $age }
}
@{ found = $true; offline = [bool]$p.WorkOffline; jobs = $jobs.Count; oldest = [int]$oldest } | ConvertTo-Json -Compress
''';

  static Future<String> _runPowerShell(String printerName) async {
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', _script],
      environment: {'BSG_PRINTER': printerName},
    );
    return result.stdout.toString();
  }

  /// Never throws. Anything it can not read counts as not ready: no ticket is
  /// charged on a guess.
  Future<PrinterReadiness> check(String printerName) async {
    try {
      return parse(await run(printerName).timeout(limit));
    } catch (_) {
      return PrinterReadiness.unknown;
    }
  }

  static PrinterReadiness parse(String output) {
    final Object? json;
    try {
      json = jsonDecode(output.trim());
    } on FormatException {
      return PrinterReadiness.unknown;
    }
    if (json is! Map) return PrinterReadiness.unknown;
    if (json['found'] != true) return PrinterReadiness.notFound;
    if (json['offline'] == true) return PrinterReadiness.offline;
    final oldest = json['oldest'];
    if (json['jobs'] is num && (json['jobs'] as num) > 0 && oldest is num && oldest >= kStuckJobSeconds) {
      return PrinterReadiness.stuckQueue;
    }
    return PrinterReadiness.ready;
  }
}

/// The words for a printer that is not ready.
String printerProblem(PrinterReadiness state, String? printer) => switch (state) {
      PrinterReadiness.ready => '',
      PrinterReadiness.notFound => 'Printer not found. Choose it in Printer settings.',
      PrinterReadiness.offline => 'Printer not ready: ${printer ?? ''} is off or unplugged. No coins were taken.',
      PrinterReadiness.stuckQueue => 'Printer not ready: a print is stuck in the Windows queue. No coins were taken.',
      PrinterReadiness.unknown => 'Printer not ready. No coins were taken.',
    };
