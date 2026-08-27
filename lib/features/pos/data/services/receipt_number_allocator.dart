import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/business_context.dart';

class ReceiptNumberAllocator {
  const ReceiptNumberAllocator({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  Future<String> allocate({
    required AppDatabase database,
    required BusinessContext context,
    required Register register,
    required String branchCode,
    required DateTime now,
  }) async {
    final existing =
        await (database.select(database.receiptSequences)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.registerId.equals(register.id),
            ))
            .getSingleOrNull();
    late final int sequence;
    if (existing == null) {
      sequence = 1;
      await database
          .into(database.receiptSequences)
          .insert(
            ReceiptSequencesCompanion.insert(
              id: _idGenerator.newId(),
              organizationId: context.organizationId,
              branchId: context.branchId,
              registerId: register.id,
              nextSequence: const Value(2),
              lastIssuedAt: Value(now),
              version: const Value(1),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      sequence = existing.nextSequence;
      final changed =
          await (database.update(database.receiptSequences)..where(
                (row) =>
                    row.id.equals(existing.id) &
                    row.version.equals(existing.version),
              ))
              .write(
                ReceiptSequencesCompanion(
                  nextSequence: Value(sequence + 1),
                  lastIssuedAt: Value(now),
                  version: Value(existing.version + 1),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) {
        throw const ConflictFailure(
          'The receipt sequence changed. Retry checkout.',
        );
      }
    }
    return '${_code(branchCode)}-${_code(register.code)}-'
        '${sequence.toString().padLeft(8, '0')}';
  }
}

String _code(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
