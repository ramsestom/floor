import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/misc/annotations.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/foreign_key.dart';
import 'package:floor_generator/value_object/index.dart';
import 'package:floor_generator/value_object/primary_key.dart';

class Entity {
  final ClassElement classElement;
  final String name; //name of the sql table
  final List<Field> fields;
  final PrimaryKey primaryKey;
  final List<ForeignKey> foreignKeys;
  final List<Index> indices;
  final ExecutableElement toSql;
  final ExecutableElement fromSql;
  //final String defaultFromSql;

  Entity(
    this.classElement,
    this.name,
    this.fields,
    this.primaryKey,
    this.foreignKeys,
    this.indices,
    this.fromSql,
    this.toSql
  );

  @nonNull
  String getCreateTableStatement() {
    final databaseDefinition = fields.map((field) {
      final autoIncrement =
          primaryKey.fields.contains(field) && primaryKey.autoGenerateId;
      return field.getDatabaseDefinition(autoIncrement);
    }).toList();

    final foreignKeyDefinitions =
        foreignKeys.map((foreignKey) => foreignKey.getDefinition()).toList();
    databaseDefinition.addAll(foreignKeyDefinitions);

    final primaryKeyDefinition = _createPrimaryKeyDefinition();
    if (primaryKeyDefinition != null) {
      databaseDefinition.add(primaryKeyDefinition);
    }

    return 'CREATE TABLE IF NOT EXISTS `$name` (${databaseDefinition.join(', ')})';
  }

  @nullable
  String _createPrimaryKeyDefinition() {
    if (primaryKey.autoGenerateId) {
      return null;
    } else {
      final columns =
          primaryKey.fields.map((field) => '`${field.columnName}`').join(', ');
      return 'PRIMARY KEY ($columns)';
    }
  }


  @nonNull
  String getFromSqlDefault() {
    final columnNames = fields.map((field) => field.columnName).toList();
    ConstructorElement choosedConstructor = null;
    final parameterValues = <String>[];
    final List<Field> unmappedFields = fields; //List<Field>();
    // for (ConstructorElement constructor in _classElement.constructors) {

    // }
    // for (var i = 0; i < constructorParameters.length; i++) {
    //   final parameterValue = "row['${columnNames[i]}']";
    //   final constructorParameter = constructorParameters[i];
    //   final castedParameterValue = _castParameterValue(constructorParameter.type, parameterValue);
    //   if (castedParameterValue == null) {
    //     throw _processorError.parameterTypeNotSupported(constructorParameter);
    //   }
    //   parameterValues.add(castedParameterValue);
    // }

    final StringBuffer sb = new StringBuffer();
    sb.writeln('(Map<String, dynamic> row) {');
    sb.writeln('  var e = ${choosedConstructor?.displayName ?? classElement.displayName}(${parameterValues.join(', ')});');
    for (Field field in unmappedFields){
      final String val = _castParameterValue(field.dartType, "row['${field.columnName}']");
      final String mapFunc = (field.fromSql==null)?null:(((field.fromSql.enclosingElement?.displayName!=null)?field.fromSql.enclosingElement.displayName+'.':'')+field.fromSql.displayName);
      sb.writeln('e.${field.name}='+((mapFunc!=null)?'$mapFunc($val);':'$val;')); 
    }
    sb.writeln('  return e;');
    sb.writeln('}');       
    return sb.toString();
  }
 

  @nullable
  String _castParameterValue(final DartType parameterType, final String parameterValue) 
  {
    if (isBool(parameterType)) {
      return '($parameterValue as int) != 0'; // maps int to bool
    } else if (isString(parameterType)) {
      return '$parameterValue as String';
    } else if (isInt(parameterType)) {
      return '$parameterValue as int';
    } else if (isDouble(parameterType)) {
      return '$parameterValue as double';
    } else {
      return '$parameterValue';
    }
  }

  @nonNull
  String getToSqlDefault() {
   final keyValueList = fields.map((field) {
      final columnName = field.columnName;
      final attributeValue = _getAttributeValue(field.fieldElement);
      final String mapFunc = (field.toSql==null)?null:(((field.toSql.enclosingElement?.displayName!=null)?field.toSql.enclosingElement.displayName+'.':'')+field.toSql.displayName); //(field.toSql!=null) ? (_classElement.displayName+'.'+field.toSql) : null;
      return "'$columnName': "+((mapFunc!=null)?'$mapFunc($attributeValue)':'$attributeValue');
    }).toList();

    return '(${classElement.displayName} item) => <String, dynamic>{${keyValueList.join(', ')}}';
  }

  @nonNull
  String _getAttributeValue(final FieldElement fieldElement) {
    final parameterName = fieldElement.displayName;
    return isBool(fieldElement.type)
        ? 'item.$parameterName ? 1 : 0'
        : 'item.$parameterName';
  }

  // @nonNull
  // String getValueMapping() {
  //   final keyValueList = fields.map((field) {
  //     final columnName = field.columnName;
  //     final attributeValue = _getAttributeValue(field.fieldElement);
  //     return "'$columnName': $attributeValue";
  //   }).toList();

  //   return '<String, dynamic>{${keyValueList.join(', ')}}';
  // }

  // @nonNull
  // String _getAttributeValue(final FieldElement fieldElement) {
  //   final parameterName = fieldElement.displayName;
  //   return isBool(fieldElement.type)
  //       ? 'item.$parameterName ? 1 : 0'
  //       : 'item.$parameterName';
  // }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity &&
          runtimeType == other.runtimeType &&
          classElement == other.classElement &&
          name == other.name &&
          const ListEquality<Field>().equals(fields, other.fields) &&
          primaryKey == other.primaryKey &&
          const ListEquality<ForeignKey>()
              .equals(foreignKeys, other.foreignKeys) &&
          const ListEquality<Index>().equals(indices, other.indices) &&
          fromSql == other.fromSql && 
          toSql == other.toSql;

  @override
  int get hashCode =>
      classElement.hashCode ^
      name.hashCode ^
      fields.hashCode ^
      primaryKey.hashCode ^
      foreignKeys.hashCode ^
      indices.hashCode ^
      fromSql.hashCode ^
      toSql.hashCode;

  @override
  String toString() {
    return 'Entity{classElement: $classElement, name: $name, fields: $fields, primaryKey: $primaryKey, foreignKeys: $foreignKeys, indices: $indices, fromSql: $fromSql, toSql: $toSql}';
  }
}
