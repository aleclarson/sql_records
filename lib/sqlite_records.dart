library sqlite_records;

import 'package:powersync/powersync.dart';
import 'core.dart';
import 'powersync_records.dart';

export 'core.dart';

/// Creates a [SqlRecords] instance from a [PowerSyncDatabase].
SqlRecords SqlRecordsPowerSync(PowerSyncDatabase db) =>
    PowerSyncWriteContext(db);

/// Alias for [SqlRecords] to maintain backward compatibility.
typedef SqliteRecords = SqlRecords;

/// Alias for [SqlRecordsReadonly] to maintain backward compatibility.
typedef SqliteRecordsReadonly = SqlRecordsReadonly;
