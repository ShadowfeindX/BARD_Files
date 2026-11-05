/// Comparison operators for a [FieldFilter].
enum FilterOp {
  /// `<`
  lessThan('LESS_THAN'),

  /// `<=`
  lessThanOrEqual('LESS_THAN_OR_EQUAL'),

  /// `>`
  greaterThan('GREATER_THAN'),

  /// `>=`
  greaterThanOrEqual('GREATER_THAN_OR_EQUAL'),

  /// `==`
  equal('EQUAL'),

  /// `!=`
  notEqual('NOT_EQUAL'),

  /// The array field contains the value.
  arrayContains('ARRAY_CONTAINS'),

  /// The field equals any value in the given list.
  inList('IN'),

  /// The field equals none of the values in the given list.
  notInList('NOT_IN'),

  /// The array field contains any value in the given list.
  arrayContainsAny('ARRAY_CONTAINS_ANY');

  const FilterOp(this.wireName);

  /// The REST enum name.
  final String wireName;
}

/// A query condition.
sealed class QueryFilter {
  const QueryFilter();
}

/// `field <op> value`. Comparing with `null` or NaN using [FilterOp.equal] or
/// [FilterOp.notEqual] is sent as a unary filter, as the REST API requires.
class FieldFilter extends QueryFilter {
  /// Creates a filter.
  const FieldFilter(this.field, this.op, this.value);

  /// Field path, for example `status` or `meta.owner`.
  final String field;

  /// The comparison.
  final FilterOp op;

  /// The comparison value (a list for the `in` operators).
  final Object? value;
}

/// All of [filters] must match.
class AndFilter extends QueryFilter {
  /// Creates the filter.
  const AndFilter(this.filters);

  /// The combined filters.
  final List<QueryFilter> filters;
}

/// At least one of [filters] must match.
class OrFilter extends QueryFilter {
  /// Creates the filter.
  const OrFilter(this.filters);

  /// The combined filters.
  final List<QueryFilter> filters;
}

/// One `orderBy` term.
class QueryOrder {
  /// Creates a term.
  const QueryOrder(this.field, {this.descending = false});

  /// Field path.
  final String field;

  /// Sort high to low.
  final bool descending;
}

/// A start or end position in the ordered results.
class QueryCursor {
  /// Creates a cursor over the `orderBy` fields, in order.
  const QueryCursor(this.values, {this.inclusive = true});

  /// One value per `orderBy` term.
  final List<Object?> values;

  /// Whether the results include the documents at this position (for both
  /// `startAt` and `endAt`).
  final bool inclusive;
}

/// A structured query over one collection (or every collection with the same
/// id when [allDescendants] is set).
class FirestoreQuery {
  /// Creates a query.
  const FirestoreQuery(
    this.collectionId, {
    this.allDescendants = false,
    this.where,
    this.orderBy = const [],
    this.limit,
    this.offset,
    this.startAt,
    this.endAt,
    this.select,
  });

  /// The collection id (the last path segment, not a full path).
  final String collectionId;

  /// Match the collection id at any depth under the parent.
  final bool allDescendants;

  /// The filter, or `null` for all documents.
  final QueryFilter? where;

  /// Sort terms.
  final List<QueryOrder> orderBy;

  /// Maximum number of documents.
  final int? limit;

  /// Documents to skip.
  final int? offset;

  /// Start position.
  final QueryCursor? startAt;

  /// End position.
  final QueryCursor? endAt;

  /// Field paths to return; `null` returns every field.
  final List<String>? select;
}
