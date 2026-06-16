// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_pdf_index.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOfflinePdfIndexCollection on Isar {
  IsarCollection<OfflinePdfIndex> get offlinePdfIndexs => this.collection();
}

const OfflinePdfIndexSchema = CollectionSchema(
  name: r'OfflinePdfIndex',
  id: 6651082287672867876,
  properties: {
    r'category': PropertySchema(
      id: 0,
      name: r'category',
      type: IsarType.string,
    ),
    r'downloadedAt': PropertySchema(
      id: 1,
      name: r'downloadedAt',
      type: IsarType.dateTime,
    ),
    r'fileSize': PropertySchema(
      id: 2,
      name: r'fileSize',
      type: IsarType.long,
    ),
    r'isPersistent': PropertySchema(
      id: 3,
      name: r'isPersistent',
      type: IsarType.bool,
    ),
    r'lastAccessedAt': PropertySchema(
      id: 4,
      name: r'lastAccessedAt',
      type: IsarType.dateTime,
    ),
    r'pdfId': PropertySchema(
      id: 5,
      name: r'pdfId',
      type: IsarType.string,
    ),
    r'storagePath': PropertySchema(
      id: 6,
      name: r'storagePath',
      type: IsarType.string,
    )
  },
  estimateSize: _offlinePdfIndexEstimateSize,
  serialize: _offlinePdfIndexSerialize,
  deserialize: _offlinePdfIndexDeserialize,
  deserializeProp: _offlinePdfIndexDeserializeProp,
  idName: r'id',
  indexes: {
    r'pdfId': IndexSchema(
      id: 5397193447447963901,
      name: r'pdfId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'pdfId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _offlinePdfIndexGetId,
  getLinks: _offlinePdfIndexGetLinks,
  attach: _offlinePdfIndexAttach,
  version: '3.1.0+1',
);

int _offlinePdfIndexEstimateSize(
  OfflinePdfIndex object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.pdfId.length * 3;
  bytesCount += 3 + object.storagePath.length * 3;
  return bytesCount;
}

void _offlinePdfIndexSerialize(
  OfflinePdfIndex object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.category);
  writer.writeDateTime(offsets[1], object.downloadedAt);
  writer.writeLong(offsets[2], object.fileSize);
  writer.writeBool(offsets[3], object.isPersistent);
  writer.writeDateTime(offsets[4], object.lastAccessedAt);
  writer.writeString(offsets[5], object.pdfId);
  writer.writeString(offsets[6], object.storagePath);
}

OfflinePdfIndex _offlinePdfIndexDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OfflinePdfIndex();
  object.category = reader.readString(offsets[0]);
  object.downloadedAt = reader.readDateTime(offsets[1]);
  object.fileSize = reader.readLong(offsets[2]);
  object.id = id;
  object.isPersistent = reader.readBool(offsets[3]);
  object.lastAccessedAt = reader.readDateTimeOrNull(offsets[4]);
  object.pdfId = reader.readString(offsets[5]);
  object.storagePath = reader.readString(offsets[6]);
  return object;
}

P _offlinePdfIndexDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _offlinePdfIndexGetId(OfflinePdfIndex object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _offlinePdfIndexGetLinks(OfflinePdfIndex object) {
  return [];
}

void _offlinePdfIndexAttach(
    IsarCollection<dynamic> col, Id id, OfflinePdfIndex object) {
  object.id = id;
}

extension OfflinePdfIndexByIndex on IsarCollection<OfflinePdfIndex> {
  Future<OfflinePdfIndex?> getByPdfId(String pdfId) {
    return getByIndex(r'pdfId', [pdfId]);
  }

  OfflinePdfIndex? getByPdfIdSync(String pdfId) {
    return getByIndexSync(r'pdfId', [pdfId]);
  }

  Future<bool> deleteByPdfId(String pdfId) {
    return deleteByIndex(r'pdfId', [pdfId]);
  }

  bool deleteByPdfIdSync(String pdfId) {
    return deleteByIndexSync(r'pdfId', [pdfId]);
  }

  Future<List<OfflinePdfIndex?>> getAllByPdfId(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'pdfId', values);
  }

  List<OfflinePdfIndex?> getAllByPdfIdSync(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'pdfId', values);
  }

  Future<int> deleteAllByPdfId(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'pdfId', values);
  }

  int deleteAllByPdfIdSync(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'pdfId', values);
  }

  Future<Id> putByPdfId(OfflinePdfIndex object) {
    return putByIndex(r'pdfId', object);
  }

  Id putByPdfIdSync(OfflinePdfIndex object, {bool saveLinks = true}) {
    return putByIndexSync(r'pdfId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPdfId(List<OfflinePdfIndex> objects) {
    return putAllByIndex(r'pdfId', objects);
  }

  List<Id> putAllByPdfIdSync(List<OfflinePdfIndex> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'pdfId', objects, saveLinks: saveLinks);
  }
}

extension OfflinePdfIndexQueryWhereSort
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QWhere> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension OfflinePdfIndexQueryWhere
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QWhereClause> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause>
      pdfIdEqualTo(String pdfId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pdfId',
        value: [pdfId],
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterWhereClause>
      pdfIdNotEqualTo(String pdfId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [],
              upper: [pdfId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [pdfId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [pdfId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [],
              upper: [pdfId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension OfflinePdfIndexQueryFilter
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QFilterCondition> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      downloadedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'downloadedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      downloadedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'downloadedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      downloadedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'downloadedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      downloadedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'downloadedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      fileSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fileSize',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      fileSizeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fileSize',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      fileSizeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fileSize',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      fileSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fileSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      isPersistentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPersistent',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      lastAccessedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastAccessedAt',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      lastAccessedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastAccessedAt',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      lastAccessedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastAccessedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      lastAccessedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastAccessedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      lastAccessedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastAccessedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      lastAccessedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastAccessedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pdfId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pdfId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pdfId',
        value: '',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      pdfIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pdfId',
        value: '',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storagePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
      storagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storagePath',
        value: '',
      ));
    });
  }
}

extension OfflinePdfIndexQueryObject
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QFilterCondition> {}

extension OfflinePdfIndexQueryLinks
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QFilterCondition> {}

extension OfflinePdfIndexQuerySortBy
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QSortBy> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByIsPersistent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPersistent', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByIsPersistentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPersistent', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByLastAccessedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> sortByPdfId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByPdfIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByStoragePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storagePath', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      sortByStoragePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storagePath', Sort.desc);
    });
  }
}

extension OfflinePdfIndexQuerySortThenBy
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QSortThenBy> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByIsPersistent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPersistent', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByIsPersistentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPersistent', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByLastAccessedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenByPdfId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByPdfIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByStoragePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storagePath', Sort.asc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
      thenByStoragePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storagePath', Sort.desc);
    });
  }
}

extension OfflinePdfIndexQueryWhereDistinct
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct> distinctByCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct>
      distinctByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'downloadedAt');
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct>
      distinctByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fileSize');
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct>
      distinctByIsPersistent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPersistent');
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct>
      distinctByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAccessedAt');
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct> distinctByPdfId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pdfId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct>
      distinctByStoragePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storagePath', caseSensitive: caseSensitive);
    });
  }
}

extension OfflinePdfIndexQueryProperty
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QQueryProperty> {
  QueryBuilder<OfflinePdfIndex, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<OfflinePdfIndex, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<OfflinePdfIndex, DateTime, QQueryOperations>
      downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'downloadedAt');
    });
  }

  QueryBuilder<OfflinePdfIndex, int, QQueryOperations> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileSize');
    });
  }

  QueryBuilder<OfflinePdfIndex, bool, QQueryOperations> isPersistentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPersistent');
    });
  }

  QueryBuilder<OfflinePdfIndex, DateTime?, QQueryOperations>
      lastAccessedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAccessedAt');
    });
  }

  QueryBuilder<OfflinePdfIndex, String, QQueryOperations> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pdfId');
    });
  }

  QueryBuilder<OfflinePdfIndex, String, QQueryOperations>
      storagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storagePath');
    });
  }
}
