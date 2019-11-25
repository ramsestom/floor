import 'dart:collection';

import 'package:code_builder/code_builder.dart';
import 'package:floor_generator/misc/string_utils.dart';
import 'package:floor_generator/value_object/dao.dart';
import 'package:floor_generator/value_object/deletion_method.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/field.dart' as fa; 
import 'package:floor_generator/value_object/insertion_method.dart';
import 'package:floor_generator/value_object/query_method.dart';
import 'package:floor_generator/value_object/transaction_method.dart';
import 'package:floor_generator/value_object/update_method.dart';
import 'package:floor_generator/writer/deletion_method_writer.dart';
import 'package:floor_generator/writer/insertion_method_writer.dart';
import 'package:floor_generator/writer/query_method_writer.dart';
import 'package:floor_generator/writer/transaction_method_writer.dart';
import 'package:floor_generator/writer/update_method_writer.dart';
import 'package:floor_generator/writer/writer.dart';

/// Creates the implementation of a DAO.
class DaoWriter extends Writer {
  final Dao dao;

  DaoWriter(this.dao);

  @override
  Class write() {
    const databaseFieldName = 'database';
    const changeListenerFieldName = 'changeListener';

    final daoName = dao.name;
    final classBuilder = ClassBuilder()
      ..name = '_\$$daoName'
      ..extend = refer(daoName)
      ..fields
          .addAll(_createFields(databaseFieldName, changeListenerFieldName));

    final databaseParameter = Parameter((builder) => builder
      ..name = databaseFieldName
      ..toThis = true);

    final changeListenerParameter = Parameter((builder) => builder
      ..name = changeListenerFieldName
      ..toThis = true);

    final constructorBuilder = ConstructorBuilder()
      ..requiredParameters.addAll([databaseParameter, changeListenerParameter]);

    final streamEntities = dao.streamEntities;

    final Set<Entity> daoEntities = Set<Entity>();

    final queryMethods = dao.queryMethods;
    if (queryMethods.isNotEmpty) {
      classBuilder
        ..fields.add(Field((builder) => builder
          ..modifier = FieldModifier.final$
          ..name = '_queryAdapter'
          ..type = refer('QueryAdapter')));

      final requiresChangeListener = streamEntities.isNotEmpty;

      constructorBuilder
        ..initializers.add(Code(
            "_queryAdapter = QueryAdapter(database${requiresChangeListener ? ', changeListener' : ''})"));

      daoEntities.addAll( queryMethods
          .map((method) => method.entity)
          .where((entity) => entity != null)
          .toSet());
    }

    final insertionMethods = dao.insertionMethods;
    if (insertionMethods.isNotEmpty) {
      final entities = insertionMethods.map((method) => method.entity).toSet();

      for (final entity in entities) {
        final entityClassName = entity.classElement.displayName;
        final fieldName = '_${decapitalize(entityClassName)}InsertionAdapter';
        final type = refer('InsertionAdapter<$entityClassName>');

        final field = Field((builder) => builder
          ..name = fieldName
          ..type = type
          ..modifier = FieldModifier.final$);

        classBuilder..fields.add(field);

        //final valueMapper = '(${entity.classElement.displayName} item) => ${entity.getValueMapping()}';
        daoEntities.add(entity);

        final requiresChangeListener =
            streamEntities.any((streamEntity) => streamEntity == entity);

        constructorBuilder
          ..initializers.add(Code("$fieldName = InsertionAdapter(database, '${entity.name}', _${decapitalize(entity.name)}2map${requiresChangeListener ? ', changeListener' : ''})"));
      }
    }

    final updateMethods = dao.updateMethods;
    if (updateMethods.isNotEmpty) {
      final entities = updateMethods.map((method) => method.entity).toSet();

      for (final entity in entities) {
        final entityClassName = entity.classElement.displayName;
        final fieldName = '_${decapitalize(entityClassName)}UpdateAdapter';
        final type = refer('UpdateAdapter<$entityClassName>');

        final field = Field((builder) => builder
          ..name = fieldName
          ..type = type
          ..modifier = FieldModifier.final$);

        classBuilder..fields.add(field);

        //final valueMapper = '(${entity.classElement.displayName} item) => ${entity.getValueMapping()}';
        daoEntities.add(entity);

        final requiresChangeListener =
            streamEntities.any((streamEntity) => streamEntity == entity);

        constructorBuilder
          ..initializers.add(Code("$fieldName = UpdateAdapter(database, '${entity.name}', ${entity.primaryKey.fields.map((field) => '\'${field.columnName}\'').toList()}, _${decapitalize(entity.name)}2map${requiresChangeListener ? ', changeListener' : ''})"));
      }
    }

    final deleteMethods = dao.deletionMethods;
    if (deleteMethods.isNotEmpty) {
      final entities = deleteMethods.map((method) => method.entity).toSet();

      for (final entity in entities) {
        final entityClassName = entity.classElement.displayName;
        final fieldName = '_${decapitalize(entityClassName)}DeletionAdapter';
        final type = refer('DeletionAdapter<$entityClassName>');

        final field = Field((builder) => builder
          ..name = fieldName
          ..type = type
          ..modifier = FieldModifier.final$);

        classBuilder..fields.add(field);

        //final valueMapper = '(${entity.classElement.displayName} item) => ${entity.getValueMapping()}';
        daoEntities.add(entity);

        final requiresChangeListener =
            streamEntities.any((streamEntity) => streamEntity == entity);

        constructorBuilder
          ..initializers.add(Code("$fieldName = DeletionAdapter(database, '${entity.name}', ${entity.primaryKey.fields.map((field) => '\'${field.columnName}\'').toList()}, _${decapitalize(entity.name)}2map${requiresChangeListener ? ', changeListener' : ''})"));
      }
    }

    Set<Reference> extrefs = HashSet();
    for (Entity entity in daoEntities) 
    {
      String mapper = (entity.fromSql==null)?entity.getFromSqlDefault():(((entity.fromSql.enclosingElement?.displayName!=null)?(entity.fromSql.enclosingElement.displayName+'.'):'')+entity.fromSql.displayName); 

      final fromSqlField = Field((builder) => builder
        ..name = '_map2${decapitalize(entity.name)}'
        ..modifier = FieldModifier.final$
        ..static = true
        ..type = refer('Function')
        ..assignment = Code('$mapper'));

      classBuilder.fields.add(fromSqlField);

      mapper = (entity.toSql==null)?entity.getToSqlDefault():(((entity.toSql.enclosingElement?.displayName!=null)?(entity.toSql.enclosingElement.displayName+'.'):'')+entity.toSql.displayName);  

      final toSqlField = Field((builder) => builder
        ..name = '_${decapitalize(entity.name)}2map'
        ..modifier = FieldModifier.final$
        ..static = true
        ..type = refer('Function')
        ..assignment = Code('$mapper'));

      classBuilder.fields.add(toSqlField);

      // //TODO: add types to import for functions
      // for (fa.Field field in entity.fields){
      //   if (field.toSql?.enclosingElement!=null){
      //     print("Found Import requested : "+field.toSql.enclosingElement.displayName+"\tlocencoding: "+field.toSql.enclosingElement.location.encoding+"\tlib: "+field.toSql.enclosingElement.library.toString());
      //     extrefs.add(Reference(field.toSql.enclosingElement.displayName, field.toSql.enclosingElement.location.encoding));
      //   }
      //   if (field.fromSql?.enclosingElement!=null){
      //     print("Found Import requested : "+field.fromSql.enclosingElement.displayName+"\tlocencoding: "+field.fromSql.enclosingElement.location.encoding+"\tlib: "+field.fromSql.enclosingElement.library.toString());
      //     extrefs.add(Reference(field.fromSql.enclosingElement.displayName, field.fromSql.enclosingElement.location.encoding));
      //   }
      // }
      
    }
    classBuilder.types.addAll(extrefs);
    

    classBuilder
      ..constructors.add(constructorBuilder.build())
      ..methods.addAll(_generateQueryMethods(queryMethods))
      ..methods.addAll(_generateInsertionMethods(insertionMethods))
      ..methods.addAll(_generateUpdateMethods(updateMethods))
      ..methods.addAll(_generateDeletionMethods(deleteMethods))
      ..methods.addAll(_generateTransactionMethods(dao.transactionMethods));

    return classBuilder.build();
  }

  List<Field> _createFields(
    final String databaseName,
    final String changeListenerName,
  ) {
    final databaseField = Field((builder) => builder
      ..name = databaseName
      ..type = refer('sqflite.DatabaseExecutor')
      ..modifier = FieldModifier.final$);

    final changeListenerField = Field((builder) => builder
      ..name = changeListenerName
      ..type = refer('StreamController<String>')
      ..modifier = FieldModifier.final$);

    return [databaseField, changeListenerField];
  }

  List<Method> _generateInsertionMethods(
    final List<InsertionMethod> insertionMethods,
  ) {
    return insertionMethods
        .map((method) => InsertionMethodWriter(method).write())
        .toList();
  }

  List<Method> _generateUpdateMethods(
    final List<UpdateMethod> updateMethods,
  ) {
    return updateMethods
        .map((method) => UpdateMethodWriter(method).write())
        .toList();
  }

  List<Method> _generateDeletionMethods(
    final List<DeletionMethod> deletionMethods,
  ) {
    return deletionMethods
        .map((method) => DeletionMethodWriter(method).write())
        .toList();
  }

  List<Method> _generateQueryMethods(final List<QueryMethod> queryMethods) {
    return queryMethods
        .map((method) => QueryMethodWriter(method).write())
        .toList();
  }

  List<Method> _generateTransactionMethods(
    final List<TransactionMethod> transactionMethods,
  ) {
    return transactionMethods
        .map((method) => TransactionMethodWriter(method).write())
        .toList();
  }
}
