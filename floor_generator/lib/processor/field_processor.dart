import 'package:analyzer/dart/element/element.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations
    show ColumnInfo;
import 'package:floor_generator/misc/annotations.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:source_gen/source_gen.dart';

class FieldProcessor extends Processor<Field> {
  final FieldElement _fieldElement;

  final _columnInfoTypeChecker = typeChecker(annotations.ColumnInfo);

  FieldProcessor(final FieldElement fieldElement)
      : assert(fieldElement != null),
        _fieldElement = fieldElement;

  @nonNull
  @override
  Field process() {
    final name = _fieldElement.name;
    final hasColumnInfoAnnotation = _columnInfoTypeChecker.hasAnnotationOfExact(_fieldElement);
    final columnName = _getColumnName(hasColumnInfoAnnotation, name);
    final isNullable = _getIsNullable(hasColumnInfoAnnotation);
    final isIgnored = _getIsIgnored(hasColumnInfoAnnotation);
    final sqlType = _getSqlType(hasColumnInfoAnnotation);
    final fromSql = _getFromSqlMapper(hasColumnInfoAnnotation);
    final toSql = _getToSqlMapper(hasColumnInfoAnnotation);
    
    return Field(
      _fieldElement,
      name,
      columnName,
      isNullable,
      isIgnored,
      sqlType,
      _fieldElement.type,
      fromSql,
      toSql
    );
  }

  @nonNull
  String _getColumnName(bool hasColumnInfoAnnotation, String name) {
    return hasColumnInfoAnnotation
        ? _columnInfoTypeChecker
                .firstAnnotationOfExact(_fieldElement)
                .getField(AnnotationField.COLUMN_INFO_NAME)
                ?.toStringValue() ??
            name
        : name;
  }

  @nonNull
  bool _getIsNullable(bool hasColumnInfoAnnotation) {
    return hasColumnInfoAnnotation
        ? _columnInfoTypeChecker
                .firstAnnotationOfExact(_fieldElement)
                .getField(AnnotationField.COLUMN_INFO_NULLABLE)
                ?.toBoolValue() ??
            true
        : true; // all Dart fields are nullable by default
  }

  @nonNull
  bool _getIsIgnored(bool hasColumnInfoAnnotation) {
    return hasColumnInfoAnnotation
        ? _columnInfoTypeChecker
                .firstAnnotationOfExact(_fieldElement)
                .getField(AnnotationField.COLUMN_INFO_IGNORE)
                ?.toBoolValue() ??
            false
        : false;
  }


  @nonNull
  String _getSqlType(bool hasColumnInfoAnnotation) {
    return hasColumnInfoAnnotation
        ? _columnInfoTypeChecker
            .firstAnnotationOfExact(_fieldElement)
            .getField(AnnotationField.COLUMN_INFO_SQLTYPE)
            ?.toStringValue() ??
            _getSqlTypeAuto()
        : _getSqlTypeAuto();
  }

  @nonNull
  String _getSqlTypeAuto() {
    final type = _fieldElement.type;
    if (isInt(type) || isBool(type)) {
      return SqlType.INTEGER;
    } else if (isDouble(type)) {
      return SqlType.REAL;
    } else if (isString(type)) {
      return SqlType.TEXT;
    } 
    return SqlType.BLOB;
    //throw InvalidGenerationSourceError(
    //  'Column type is not supported for $type.',
    //  element: _fieldElement,
    //);
  }


  @nonNull
  ExecutableElement _getToSqlMapper(bool hasColumnInfoAnnotation) {
    return hasColumnInfoAnnotation
        ? _columnInfoTypeChecker
            .firstAnnotationOfExact(_fieldElement)
            .getField(AnnotationField.COLUMN_INFO_TOSQL)
            ?.toFunctionValue() 
        : null;
  }

  @nonNull
  ExecutableElement _getFromSqlMapper(bool hasColumnInfoAnnotation) {
    return hasColumnInfoAnnotation
        ? _columnInfoTypeChecker
            .firstAnnotationOfExact(_fieldElement)
            .getField(AnnotationField.COLUMN_INFO_FROMSQL)
            ?.toFunctionValue() 
        : null;
  }


  // @nonNull
  // String _getToSqlMapper(bool hasColumnInfoAnnotation) {
  //   if (!hasColumnInfoAnnotation){return null;}
  //   final ExecutableElement fe = _columnInfoTypeChecker.firstAnnotationOfExact(_fieldElement).getField(AnnotationField.COLUMN_INFO_TOSQL)?.toFunctionValue();
  //   if (fe!=null){
  //     return ((fe.enclosingElement!=null)?fe.enclosingElement.displayName+'.':'')+fe.displayName;
  //   }
  //   return null;
  // }

  // @nonNull
  // String _getFromSqlMapper(bool hasColumnInfoAnnotation) {
  //   if (!hasColumnInfoAnnotation){return null;}
  //   final ExecutableElement fe = _columnInfoTypeChecker.firstAnnotationOfExact(_fieldElement).getField(AnnotationField.COLUMN_INFO_FROMSQL)?.toFunctionValue();
  //   if (fe!=null){
  //     return ((fe.enclosingElement!=null)?fe.enclosingElement.displayName+'.':'')+fe.displayName;
  //   }
  //   return null;
  // }

}
