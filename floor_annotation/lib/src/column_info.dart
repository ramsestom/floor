/// Allows customization of the column associated with this field.
class ColumnInfo {
  /// The custom name of the column.
  final String name;

  /// Defines if the associated column is allowed to contain 'null'.
  final bool nullable;

  /// Defines if the associated column should be ignored.
  final bool ignore;

  //allows to enforce the SQL type that would be used to store this field in the database
  final String sqlType;

  /// A [Function] to use when encoding the annotated field to the associated sql value.
  ///
  /// Must be a top-level or static [Function] that takes one argument mapping
  /// a value compatible with the type of the annotated field to an sql literal.
  ///
  /// When creating a field that supports both `toSql` and `fromSql`
  /// you should also set [toSql] if you set [fromSql].
  /// Values returned by [toSql] should "round-trip" through [fromSql].
  final Function toSql; 

  /// A [Function] to use when decoding the associated sql value to the annotated field.
  ///
  /// Must be a top-level or static [Function] that takes one argument mapping
  /// an sql literal to a value compatible with the type of the annotated field.
  ///
  /// When creating a field that supports both `toSql` and `fromSql`
  /// you should also set [toSql] if you set [fromSql].
  /// Values returned by [toSql] should "round-trip" through [fromSql].
  final Function fromSql; 


  const ColumnInfo({this.name, this.nullable = true, this.ignore, this.sqlType, this.toSql, this.fromSql});

}
