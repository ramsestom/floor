import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:floor_generator/misc/extension/set_extension.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/misc/extension/type_converter_element_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/error/queryable_processor_error.dart';
import 'package:floor_generator/processor/field_processor.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/queryable.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

abstract class QueryableProcessor<T extends Queryable> extends Processor<T> {
  final QueryableProcessorError _queryableProcessorError;

  @protected
  final ClassElement classElement;

  final Set<TypeConverter> queryableTypeConverters;

  @protected
  QueryableProcessor(
    this.classElement,
    final Set<TypeConverter> typeConverters,
  )   : _queryableProcessorError = QueryableProcessorError(classElement),
        queryableTypeConverters = typeConverters +
            classElement.getTypeConverters(TypeConverterScope.queryable);

  @protected
  List<Field> getFields() {
    if (classElement.mixins.isNotEmpty) {
      throw _queryableProcessorError.prohibitedMixinUsage;
    }
    final fields = [
      ...classElement.fields,
      ...classElement.allSupertypes.expand((type) => type.element.fields),
    ];

    return fields
        .where((fieldElement) => fieldElement.shouldBeIncluded())
        .map((field) {
      final typeConverter =
          queryableTypeConverters.getClosestOrNull(field.type);
      return FieldProcessor(field, typeConverter).process();
    }).toList();
  }

  @protected
  String getMapper(final List<Field> fields) {
    final List<ParameterElement> constructorParameters = classElement.constructors.first.parameters;
    final List<Field> nonconstructorFields = List.from(fields);
    final List<String> parameterValues = [];
    for (ParameterElement parameterElement in constructorParameters){
      final Field? pfield = _getMatchingField(parameterElement, nonconstructorFields);
      if (pfield!=null){
        final String? pval = _getElementValue(pfield, parameterElement.type, parameterElement);
        if (pval!=null){
          parameterValues.add(((parameterElement.isNamed)?'${parameterElement.displayName}: ':'')+pval);
        }
        nonconstructorFields.remove(pfield);
      }
    }

    String mapper = '(Map<String, Object?> row) => ${classElement.displayName}(${parameterValues.join(', ')})';
    //if (nonconstructorFields.length<4){
    for (Field ncpfield in nonconstructorFields){
      if (_isFieldWithGetterAndSetter(ncpfield.fieldElement)){
        mapper+='..${ncpfield.name}=(${_getElementValue(ncpfield, ncpfield.fieldElement.type, ncpfield.fieldElement)})';
      }
    }
    //}

    return mapper;
  }


  static bool _isFieldWithGetterAndSetter(final FieldElement fieldElement) {
    return fieldElement.getter!=null && fieldElement.setter!=null ;
  }

  /// Returns `null` if no matching field could be found
  Field? _getMatchingField(
    final ParameterElement parameterElement,
    final List<Field> fields,
  ) {
    final parameterName = parameterElement.displayName;
    final field = fields.firstWhereOrNull((field) => field.name == parameterName);
    return field;
  }

  /// Returns `null` whenever field is @ignored
  String? _getElementValue(
    final Field? field,
    final DartType type,
    [final Element? element]
  ) {
    if (field != null) {
      final databaseValue = "row['${field.columnName}']";

      String parameterValue;

      if (type.isDefaultSqlType) {
        parameterValue = databaseValue.cast(
          type,
          element,
        );
      } else {
        // final typeConverter = [...queryableTypeConverters, field.typeConverter]
        //     .whereNotNull()
        //     .getClosest(parameterElement.type);
        // final castedDatabaseValue = databaseValue.cast(
        //   typeConverter.databaseType,
        //   parameterElement,
        // );

        // parameterValue =
        //     '_${typeConverter.name.decapitalize()}.decode($castedDatabaseValue)';


        final bool nullableAttribute = type != type.promoteNonNullable();
        final Iterable<TypeConverter> typeConverters = [
          ...queryableTypeConverters,
          field.typeConverter,
        ].whereNotNull();
        bool mustadatptonull = false;
        TypeConverter? typeConverter = typeConverters.getClosestOrNull(type);
        if (typeConverter==null && nullableAttribute){
          typeConverter = typeConverters.getClosestOrNull(type.promoteNonNullable());
          mustadatptonull = true;
        }
        if (typeConverter==null){
          throw InvalidGenerationSourceError(
            'Column type is not supported for $type',
            todo: 'Either use a supported type or supply a type converter.',
          );
        }

        bool adatptdbtypetonull = false;
        if (mustadatptonull && typeConverter.databaseType==typeConverter.databaseType.promoteNonNullable()){
          adatptdbtypetonull = true;
        }

        final castedDatabaseValue = databaseValue.cast(
          typeConverter.databaseType,
          element,
        )+(adatptdbtypetonull?'?':'');

        parameterValue = (mustadatptonull?'(($castedDatabaseValue)==null)?null:':'')+
             '_${typeConverter.name.decapitalize()}.decode('+(mustadatptonull?'(':'')+'$castedDatabaseValue'+(mustadatptonull?')!':'')+')';
      
      }

      return parameterValue; // also covers positional parameter
    } else {
      return null;
    }
  }
}

extension on String {
  String cast(DartType dartType, Element? element) {
    if (dartType.isDartCoreBool) {
      if (dartType.isNullable) {
        // if the value is null, return null
        // if the value is not null, interpret 1 as true and 0 as false
        return '$this == null ? null : ($this as int) != 0';
      } else {
        return '($this as int) != 0';
      }
    } else if (dartType.isDartCoreString ||
        dartType.isDartCoreInt ||
        dartType.isUint8List ||
        dartType.isDartCoreDouble) {
      final typeString = dartType.getDisplayString(withNullability: true);
      return '$this as $typeString';
    } else {
      throw InvalidGenerationSourceError(
        'Trying to convert unsupported type $dartType.',
        todo: 'Consider adding a type converter.',
        element: element,
      );
    }
  }
}

extension on FieldElement {
  bool shouldBeIncluded() {
    final isIgnored = hasAnnotation(annotations.ignore.runtimeType);
    return !(isStatic || isSynthetic || isIgnored);
  }
}
