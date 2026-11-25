import 'package:flutter/material.dart';

class Category {
  final String id;
  final String title;
  final IconData icon;
  const Category(this.id, this.title, this.icon);
}

/// Каждой категории соответствует файл `assets/words/<id>.txt`, одно слово на строку.
const categories = <Category>[
  Category('kids', 'Для детей', Icons.child_care),
  Category('animals', 'Животные', Icons.pets),
  Category('food', 'Еда и напитки', Icons.restaurant),
  Category('household', 'Дом и быт', Icons.chair),
  Category('items', 'Предметы и инструменты', Icons.handyman),
  Category('nature', 'Природа и погода', Icons.landscape),
  Category('plants', 'Растения и грибы', Icons.local_florist),
  Category('professions', 'Профессии', Icons.engineering),
  Category('city', 'Город и места', Icons.location_city),
  Category('transport', 'Транспорт', Icons.directions_car),
  Category('geography', 'География', Icons.public),
  Category('sport', 'Спорт', Icons.sports_soccer),
  Category('body', 'Тело и здоровье', Icons.accessibility_new),
  Category('clothes', 'Одежда и красота', Icons.checkroom),
  Category('school', 'Школа и учёба', Icons.school),
  Category('holidays', 'Праздники и отдых', Icons.celebration),
  Category('actions', 'Действия', Icons.directions_run),
  Category('emotions', 'Чувства и характер', Icons.mood),
  Category('tech', 'Техника и интернет', Icons.devices),
  Category('science', 'Наука', Icons.science),
  Category('music', 'Музыка', Icons.music_note),
  Category('movies', 'Кино и мультфильмы', Icons.movie),
  Category('art', 'Искусство и культура', Icons.palette),
  Category('fantasy', 'Сказки и фэнтези', Icons.auto_fix_high),
  Category('history', 'История', Icons.history_edu),
  Category('famous', 'Знаменитости', Icons.star),
  Category('work', 'Работа и деньги', Icons.business_center),
  Category('abstract', 'Абстрактные понятия', Icons.psychology),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
