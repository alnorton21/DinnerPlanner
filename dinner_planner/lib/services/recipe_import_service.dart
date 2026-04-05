import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';


class ImportedRecipe {
  final String name;
  final String instructions;
  final int servings;
  final String? imageUrl;
  final String sourceUrl;
  final List<ParsedIngredient> ingredients;

  const ImportedRecipe({
    required this.name,
    required this.instructions,
    required this.servings,
    required this.sourceUrl,
    this.imageUrl,
    this.ingredients = const [],
  });
}

class ParsedIngredient {
  final String name;
  final double quantity;
  final String unit;

  const ParsedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}

/// Reason an import failed — surfaced to the UI for a better error message.
enum ImportFailure { network, blocked, noRecipe }

class RecipeImportService {
  static const _unitMap = {
    'cup': 'cup', 'cups': 'cup',
    'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp': 'tbsp', 'tbs': 'tbsp',
    'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp': 'tsp',
    'ounce': 'oz', 'ounces': 'oz', 'oz': 'oz',
    'pound': 'lb', 'pounds': 'lb', 'lb': 'lb', 'lbs': 'lb',
    'gram': 'g', 'grams': 'g', 'g': 'g',
    'kilogram': 'kg', 'kilograms': 'kg', 'kg': 'kg',
  };

  /// Returns an [ImportedRecipe] on success, or throws an [ImportException].
  static Future<ImportedRecipe> importFromUrl(String url) async {
    // Route through Supabase Edge Function so the request comes from a
    // server IP — avoids Cloudflare / bot-detection blocks on recipe sites.
    String html;
    try {
      final res = await Supabase.instance.client.functions
          .invoke('recipe-fetch', body: {'url': url.trim()})
          .timeout(const Duration(seconds: 20));

      final data = res.data as Map<String, dynamic>?;
      if (data == null) throw ImportException(ImportFailure.network);

      if (data.containsKey('error')) {
        final err = data['error'] as String;
        if (err == 'blocked') throw ImportException(ImportFailure.blocked);
        throw ImportException(ImportFailure.network);
      }

      html = data['html'] as String? ?? '';
      if (html.isEmpty) throw ImportException(ImportFailure.noRecipe);
    } on ImportException {
      rethrow;
    } catch (_) {
      // Edge Function unavailable — fall back to direct fetch
      html = await _directFetch(url);
    }

    // Try JSON-LD first (most reliable — used by AllRecipes, Food Network, NYT Cooking, etc.)
    final jsonLdBlocks = _extractJsonLdBlocks(html);
    for (final block in jsonLdBlocks) {
      final recipe = _findRecipeInBlock(block);
      if (recipe != null) return _parseRecipe(recipe, url);
    }

    // Fallback: scan ALL <script> tags for any JSON containing a Recipe @type.
    // Catches sites that use type="application/json" or embed data in JS variables.
    final allScriptContents = _extractAllScriptContents(html);
    for (final content in allScriptContents) {
      final recipe = _findRecipeInBlock(content);
      if (recipe != null) return _parseRecipe(recipe, url);
    }

    throw ImportException(ImportFailure.noRecipe);
  }

  // ── Direct fetch fallback (used when Edge Function is unavailable) ─────────

  static const _directHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  static Future<String> _directFetch(String url) async {
    final uri = Uri.parse(url.trim());
    final http.Response response;
    try {
      response = await http.get(uri, headers: _directHeaders)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ImportException(ImportFailure.network);
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw ImportException(ImportFailure.blocked);
    }
    if (response.statusCode != 200) {
      throw ImportException(ImportFailure.network);
    }
    return response.body;
  }

  // ── Extraction helpers ─────────────────────────────────────────────────────

  static List<String> _extractJsonLdBlocks(String html) {
    // Match <script type="application/ld+json"> with any attribute ordering / spacing
    final pattern = RegExp(
      r'''<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    );
    return pattern.allMatches(html).map((m) => (m.group(1) ?? '').trim()).toList();
  }

  static List<String> _extractAllScriptContents(String html) {
    // Grab content of every <script> tag that contains "Recipe" to limit scope
    final pattern = RegExp(
      r'<script[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    );
    return pattern
        .allMatches(html)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.contains('"Recipe"') || s.contains(r'\/Recipe'))
        .toList();
  }

  static Map<String, dynamic>? _findRecipeInBlock(String raw) {
    // Strip JS variable wrappers like "window.__data = {...}" before parsing
    final cleaned = raw
        .replaceFirst(RegExp(r'^[^{\[]+'), '') // drop leading non-JSON chars
        .replaceAll(RegExp(r';\s*$'), '');     // drop trailing semicolon
    if (cleaned.isEmpty) return null;

    try {
      final decoded = jsonDecode(cleaned);
      return _searchForRecipe(decoded);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _searchForRecipe(dynamic node) {
    if (node is Map<String, dynamic>) {
      if (_isRecipeType(node['@type'])) return node;
      // Look inside @graph
      final graph = node['@graph'];
      if (graph is List) {
        for (final item in graph) {
          final found = _searchForRecipe(item);
          if (found != null) return found;
        }
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _searchForRecipe(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Handles plain "Recipe", full URLs like "https://schema.org/Recipe",
  /// and arrays of types (many sites mix ["Recipe", "NewsArticle"]).
  static bool _isRecipeType(dynamic type) {
    if (type is String) {
      return type == 'Recipe' ||
          type.endsWith('/Recipe') ||
          type.endsWith('/recipe');
    }
    if (type is List) {
      return type.any((t) => t is String && _isRecipeType(t));
    }
    return false;
  }

  // ── Recipe parsing ─────────────────────────────────────────────────────────

  static ImportedRecipe _parseRecipe(Map<String, dynamic> json, String sourceUrl) {
    final name = (json['name'] as String? ?? 'Imported Recipe').trim();
    final instructions = _parseInstructions(json['recipeInstructions']);
    final servings = _parseServings(json['recipeYield']);
    final imageUrl = _parseImage(json['image']);

    final rawIngredients = json['recipeIngredient'];
    final ingredients = <ParsedIngredient>[];
    if (rawIngredients is List) {
      for (final ing in rawIngredients) {
        if (ing is String && ing.trim().isNotEmpty) {
          final parsed = parseIngredient(ing.trim());
          if (parsed != null) ingredients.add(parsed);
        }
      }
    }

    return ImportedRecipe(
      name: name,
      instructions: instructions,
      servings: servings,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      ingredients: ingredients,
    );
  }

  static String _parseInstructions(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return _stripHtml(raw);
    if (raw is List) {
      final steps = <String>[];
      for (int i = 0; i < raw.length; i++) {
        final step = raw[i];
        if (step is String) {
          steps.add('${i + 1}. ${_stripHtml(step)}');
        } else if (step is Map) {
          // HowToStep — may have 'text' or nested 'itemListElement'
          final text = step['text'] as String?;
          if (text != null && text.isNotEmpty) {
            steps.add('${i + 1}. ${_stripHtml(text)}');
          } else {
            final sub = step['itemListElement'];
            if (sub is List) {
              for (final s in sub) {
                if (s is Map) {
                  final t = s['text'] as String? ?? '';
                  if (t.isNotEmpty) steps.add('${steps.length + 1}. ${_stripHtml(t)}');
                }
              }
            }
          }
        }
      }
      return steps.join('\n\n');
    }
    return '';
  }

  static int _parseServings(dynamic raw) {
    if (raw == null) return 1;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is List && raw.isNotEmpty) return _parseServings(raw.first);
    if (raw is String) {
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match != null) return int.tryParse(match.group(0)!) ?? 1;
    }
    return 1;
  }

  static String? _parseImage(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.isNotEmpty ? raw : null;
    if (raw is List && raw.isNotEmpty) return _parseImage(raw.first);
    if (raw is Map) return (raw['url'] as String?)?.isNotEmpty == true ? raw['url'] : null;
    return null;
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── Ingredient parsing ─────────────────────────────────────────────────────

  static ParsedIngredient? parseIngredient(String text) {
    text = _stripHtml(text)
        .replaceAll(RegExp(r'\([^)]*\)'), '') // strip parenthetical notes
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) return null;

    // "2 cups flour", "1/2 tsp salt", "1 1/2 lb chicken breast"
    final pattern = RegExp(
      r'^(\d+(?:\s+\d+\/\d+|\.\d+|\/\d+)?)\s+([a-zA-Z]{1,15})\.?\s+([\s\S]+)$',
    );
    final match = pattern.firstMatch(text);
    if (match != null) {
      final qty = _parseFraction(match.group(1)!.trim());
      final unitRaw = match.group(2)!.trim().toLowerCase();
      final name = match.group(3)!.replaceAll(RegExp(r',.*$'), '').trim();
      final unit = _unitMap[unitRaw] ?? 'item';
      return ParsedIngredient(name: name, quantity: qty, unit: unit);
    }

    // "3 eggs", "2 bananas"
    final simpleMatch = RegExp(r'^(\d+(?:\.\d+)?)\s+([\s\S]+)$').firstMatch(text);
    if (simpleMatch != null) {
      return ParsedIngredient(
        name: simpleMatch.group(2)!.trim(),
        quantity: double.tryParse(simpleMatch.group(1)!) ?? 1.0,
        unit: 'item',
      );
    }

    // "salt", "pepper to taste"
    return ParsedIngredient(name: text, quantity: 1.0, unit: 'item');
  }

  static double _parseFraction(String s) {
    final mixed = RegExp(r'^(\d+)\s+(\d+)\/(\d+)$').firstMatch(s);
    if (mixed != null) {
      return double.parse(mixed.group(1)!) +
          double.parse(mixed.group(2)!) / double.parse(mixed.group(3)!);
    }
    final fraction = RegExp(r'^(\d+)\/(\d+)$').firstMatch(s);
    if (fraction != null) {
      return double.parse(fraction.group(1)!) / double.parse(fraction.group(2)!);
    }
    return double.tryParse(s) ?? 1.0;
  }
}

class ImportException implements Exception {
  final ImportFailure failure;
  const ImportException(this.failure);
}

// ── Text-paste parsing ──────────────────────────────────────────────────────

class ParsedRecipeText {
  final List<ParsedIngredient> ingredients;
  final String instructions;
  const ParsedRecipeText({required this.ingredients, required this.instructions});
}

extension RecipeTextParser on RecipeImportService {
  // Static entry point — call as RecipeImportService.parseRecipeText(text)
  static ParsedRecipeText parseRecipeText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    // Section header patterns
    final ingredientRe = RegExp(r'^ingredients?:?\s*$', caseSensitive: false);
    final instructionRe = RegExp(
      r'^(instructions?|directions?|method|steps?|preparation|how to( make| cook| prepare)?):?\s*$',
      caseSensitive: false,
    );

    int ingredientStart = -1;
    int instructionStart = -1;

    for (int i = 0; i < lines.length; i++) {
      if (ingredientRe.hasMatch(lines[i]) && ingredientStart < 0) {
        ingredientStart = i + 1;
      } else if (instructionRe.hasMatch(lines[i]) && instructionStart < 0) {
        instructionStart = i + 1;
      }
    }

    List<String> ingredientLines;
    List<String> instructionLines;

    if (ingredientStart >= 0) {
      // Clear "Ingredients:" section found
      final end = (instructionStart > ingredientStart)
          ? instructionStart - 1
          : lines.length;
      ingredientLines =
          lines.sublist(ingredientStart, end).where((l) => l.isNotEmpty).toList();
      instructionLines = instructionStart > 0
          ? lines.sublist(instructionStart).where((l) => l.isNotEmpty).toList()
          : [];
    } else {
      // No headers — classify each line by heuristic
      ingredientLines = [];
      instructionLines = [];
      for (final line in lines) {
        if (line.isEmpty) continue;
        if (_looksLikeIngredientLine(line)) {
          ingredientLines.add(line);
        } else {
          instructionLines.add(line);
        }
      }
    }

    final ingredients = ingredientLines
        .map(RecipeImportService.parseIngredient)
        .whereType<ParsedIngredient>()
        .toList();

    // Number instruction lines that aren't already numbered
    final numbered = <String>[];
    int stepNum = 1;
    for (final line in instructionLines) {
      final alreadyNumbered = RegExp(r'^\d+[.)]\s').hasMatch(line);
      numbered.add(alreadyNumbered ? line : '$stepNum. $line');
      stepNum++;
    }

    return ParsedRecipeText(
      ingredients: ingredients,
      instructions: numbered.join('\n\n'),
    );
  }

  static bool _looksLikeIngredientLine(String line) {
    if (line.length > 120) return false;
    // Starts with a digit but not a numbered step like "1. Heat the pan..."
    if (RegExp(r'^\d').hasMatch(line)) {
      if (RegExp(r'^\d+[.)]\s+[A-Za-z]').hasMatch(line) && line.length > 40) {
        return false;
      }
      return true;
    }
    // Unicode fractions: ½ ⅓ ⅔ ¼ ¾ ⅛ ⅜ ⅝ ⅞
    if (RegExp(r'^[½⅓⅔¼¾⅛⅜⅝⅞]').hasMatch(line)) return true;
    // Contains a recognizable unit word
    final unitRe = RegExp(
      r'\b(cups?|tbsp|tbs|tsp|tablespoons?|teaspoons?|oz|lbs?|grams?|kg|pounds?|ounces?|pinch|dash|cloves?|cans?|pkg|packages?|sticks?|slices?|pieces?)\b',
      caseSensitive: false,
    );
    return unitRe.hasMatch(line);
  }
}
