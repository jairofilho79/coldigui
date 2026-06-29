// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carousel_entry.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetCarouselEntryCollection on Isar {
  IsarCollection<int, CarouselEntry> get carouselEntrys => this.collection();
}

final CarouselEntrySchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'CarouselEntry',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'pdfId', type: IsarType.string),
      IsarPropertySchema(name: 'sortOrder', type: IsarType.long),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'pdfId',
        properties: ["pdfId"],
        unique: true,
        hash: false,
      ),
      IsarIndexSchema(
        name: 'sortOrder',
        properties: ["sortOrder"],
        unique: false,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, CarouselEntry>(
    serialize: serializeCarouselEntry,
    deserialize: deserializeCarouselEntry,
    deserializeProperty: deserializeCarouselEntryProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeCarouselEntry(IsarWriter writer, CarouselEntry object) {
  IsarCore.writeString(writer, 1, object.pdfId);
  IsarCore.writeLong(writer, 2, object.sortOrder);
  return object.id;
}

@isarProtected
CarouselEntry deserializeCarouselEntry(IsarReader reader) {
  final object = CarouselEntry();
  object.id = IsarCore.readId(reader);
  object.pdfId = IsarCore.readString(reader, 1) ?? '';
  object.sortOrder = IsarCore.readLong(reader, 2);
  return object;
}

@isarProtected
dynamic deserializeCarouselEntryProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readLong(reader, 2);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _CarouselEntryUpdate {
  bool call({required int id, String? pdfId, int? sortOrder});
}

class _CarouselEntryUpdateImpl implements _CarouselEntryUpdate {
  const _CarouselEntryUpdateImpl(this.collection);

  final IsarCollection<int, CarouselEntry> collection;

  @override
  bool call({
    required int id,
    Object? pdfId = ignore,
    Object? sortOrder = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (pdfId != ignore) 1: pdfId as String?,
            if (sortOrder != ignore) 2: sortOrder as int?,
          },
        ) >
        0;
  }
}

sealed class _CarouselEntryUpdateAll {
  int call({required List<int> id, String? pdfId, int? sortOrder});
}

class _CarouselEntryUpdateAllImpl implements _CarouselEntryUpdateAll {
  const _CarouselEntryUpdateAllImpl(this.collection);

  final IsarCollection<int, CarouselEntry> collection;

  @override
  int call({
    required List<int> id,
    Object? pdfId = ignore,
    Object? sortOrder = ignore,
  }) {
    return collection.updateProperties(id, {
      if (pdfId != ignore) 1: pdfId as String?,
      if (sortOrder != ignore) 2: sortOrder as int?,
    });
  }
}

extension CarouselEntryUpdate on IsarCollection<int, CarouselEntry> {
  _CarouselEntryUpdate get update => _CarouselEntryUpdateImpl(this);

  _CarouselEntryUpdateAll get updateAll => _CarouselEntryUpdateAllImpl(this);
}

sealed class _CarouselEntryQueryUpdate {
  int call({String? pdfId, int? sortOrder});
}

class _CarouselEntryQueryUpdateImpl implements _CarouselEntryQueryUpdate {
  const _CarouselEntryQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<CarouselEntry> query;
  final int? limit;

  @override
  int call({Object? pdfId = ignore, Object? sortOrder = ignore}) {
    return query.updateProperties(limit: limit, {
      if (pdfId != ignore) 1: pdfId as String?,
      if (sortOrder != ignore) 2: sortOrder as int?,
    });
  }
}

extension CarouselEntryQueryUpdate on IsarQuery<CarouselEntry> {
  _CarouselEntryQueryUpdate get updateFirst =>
      _CarouselEntryQueryUpdateImpl(this, limit: 1);

  _CarouselEntryQueryUpdate get updateAll =>
      _CarouselEntryQueryUpdateImpl(this);
}

class _CarouselEntryQueryBuilderUpdateImpl
    implements _CarouselEntryQueryUpdate {
  const _CarouselEntryQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<CarouselEntry, CarouselEntry, QOperations> query;
  final int? limit;

  @override
  int call({Object? pdfId = ignore, Object? sortOrder = ignore}) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (pdfId != ignore) 1: pdfId as String?,
        if (sortOrder != ignore) 2: sortOrder as int?,
      });
    } finally {
      q.close();
    }
  }
}

extension CarouselEntryQueryBuilderUpdate
    on QueryBuilder<CarouselEntry, CarouselEntry, QOperations> {
  _CarouselEntryQueryUpdate get updateFirst =>
      _CarouselEntryQueryBuilderUpdateImpl(this, limit: 1);

  _CarouselEntryQueryUpdate get updateAll =>
      _CarouselEntryQueryBuilderUpdateImpl(this);
}

extension CarouselEntryQueryFilter
    on QueryBuilder<CarouselEntry, CarouselEntry, QFilterCondition> {
  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  pdfIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  sortOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  sortOrderGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  sortOrderGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  sortOrderLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 2, value: value));
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  sortOrderLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterFilterCondition>
  sortOrderBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 2, lower: lower, upper: upper),
      );
    });
  }
}

extension CarouselEntryQueryObject
    on QueryBuilder<CarouselEntry, CarouselEntry, QFilterCondition> {}

extension CarouselEntryQuerySortBy
    on QueryBuilder<CarouselEntry, CarouselEntry, QSortBy> {
  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> sortByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> sortByPdfIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy>
  sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }
}

extension CarouselEntryQuerySortThenBy
    on QueryBuilder<CarouselEntry, CarouselEntry, QSortThenBy> {
  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> thenByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> thenByPdfIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy> thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterSortBy>
  thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }
}

extension CarouselEntryQueryWhereDistinct
    on QueryBuilder<CarouselEntry, CarouselEntry, QDistinct> {
  QueryBuilder<CarouselEntry, CarouselEntry, QAfterDistinct> distinctByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CarouselEntry, CarouselEntry, QAfterDistinct>
  distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }
}

extension CarouselEntryQueryProperty1
    on QueryBuilder<CarouselEntry, CarouselEntry, QProperty> {
  QueryBuilder<CarouselEntry, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CarouselEntry, String, QAfterProperty> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CarouselEntry, int, QAfterProperty> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}

extension CarouselEntryQueryProperty2<R>
    on QueryBuilder<CarouselEntry, R, QAfterProperty> {
  QueryBuilder<CarouselEntry, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CarouselEntry, (R, String), QAfterProperty> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CarouselEntry, (R, int), QAfterProperty> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}

extension CarouselEntryQueryProperty3<R1, R2>
    on QueryBuilder<CarouselEntry, (R1, R2), QAfterProperty> {
  QueryBuilder<CarouselEntry, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CarouselEntry, (R1, R2, String), QOperations> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CarouselEntry, (R1, R2, int), QOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}
