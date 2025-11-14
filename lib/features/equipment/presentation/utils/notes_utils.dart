import 'package:flutter/foundation.dart';

// Utilidades para procesar texto de notas
String stripOptionsFromNotes(String notes) {
  var s = notes;
  s = s.replaceAll(RegExp(r'(Marca|Marcas) posibles?:\s*[^;\n]+(;)?', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'Modelo(s)? posibles?:\s*[^;\n]+(;)?', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'(Serie|Serial)(s)? posible(s)?:\s*[^.;\n]+(;|\.)?', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return s;
}